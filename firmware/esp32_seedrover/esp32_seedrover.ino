#include <ArduinoJson.h>
#include <WebServer.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <ESP32Servo.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Preferences.h>
#include <DHT.h>

#include "secrets.h"

// Fallback Wi-Fi credentials in case secrets.h only defines ROVER_TOKEN
#ifndef WIFI_SSID
#define WIFI_SSID "MAXWELL"
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD "maxwell11"
#endif

#define SOIL_SENSOR_PIN 34
#define TEMP_SENSOR_PIN 14
#define DHT_SENSOR_PIN 25
#define DHT_SENSOR_TYPE DHT11

// Ultrasonic Sensor 1: Obstacle detection (monitors rear / notifies app)
#define REAR_ULTRASONIC_TRIG_PIN 16
#define REAR_ULTRASONIC_ECHO_PIN 17

// Ultrasonic Sensor 2: Field-end distance & boundary obstacle monitoring
#define FRONT_ULTRASONIC_TRIG_PIN 5
#define FRONT_ULTRASONIC_ECHO_PIN 15

// Dynamic field bed distance: row distance is dynamically calculated as (targetDrops * spacingCm) + FLATTENER_OVERSHOOT_CM
// Supports arbitrary distances from 1 meter to 50+ meters without hardcoded limits.
const float DEFAULT_MIN_FIELD_DISTANCE_CM = 100.0f;
const float MAX_FIELD_DISTANCE_CM = 5000.0f; // 50-meter safety cap (prevents runaway)
#define SERVO_SOIL_SENSOR_PIN 13

// 3 Seed Dispenser Gate Servos (selected based on crop/seed type)
#define SERVO_SEED_1_PIN 27     // Seed Gate 1 (Default / Calamansi)
#define SERVO_SEED_2_PIN 4      // Seed Gate 2 (Sitaw)
#define SERVO_SEED_3_PIN 23     // Seed Gate 3 (Peanut)

#define SERVO_SOIL_MECH_PIN 26  // Rake / furrow mechanism
#define SERVO_FLATTENER_PIN 33  // Soil flattener mechanism (flattens soil after being raked)
#define SERVO_MOLDER_PIN SERVO_FLATTENER_PIN // Legacy alias
// Note: Leveler (GPIO 32) and Seed Tube (GPIO 2) removed from robot build
#define SERVO_LEVELER_PIN 32
#define SERVO_SEED_TUBE_PIN 2
#define SERVO_HOLE_TUBE_PIN SERVO_SEED_TUBE_PIN
#define IN1 18
#define IN2 19
#define IN3 21
#define IN4 22

const char *FIRMWARE_VERSION = "3.0.0-raking-scout-planting";
const unsigned long SOFTAP_RESTART_DELAY_MS = 5000;
const unsigned long SOFTAP_WATCHDOG_INTERVAL_MS = 2000;
// Generous 12s timeout prevents spurious connection drops during Wi-Fi retransmission
const unsigned long APP_HEARTBEAT_TIMEOUT_MS = 12000;
const unsigned long SOIL_SETTLE_MS = 1000;
const unsigned long PLANTING_PRECHECK_MAX_AGE_MS = 60000;
const unsigned long SOIL_REFERENCE_CAPTURE_TIMEOUT_MS = 10000;
const unsigned long RAKE_SETTLE_MS = 700;
const unsigned long DHT_SAMPLE_INTERVAL_MS = 2500;
const unsigned long OBSTACLE_SAMPLE_INTERVAL_MS = 120;
const float OBSTACLE_WARN_DISTANCE_CM = 30.0f;
const float OBSTACLE_CLEAR_DISTANCE_CM = 35.0f;
const unsigned long OBSTACLE_STALE_AFTER_MS = 3000;

const unsigned long REVERSE_TOOL_SETTLE_MS = 500; // Time for rake to lift and flattener to lower before backward drive
const float FIELD_END_WALL_STOP_CM = 15.0f;       // Distance to front wall to stop forward run (avoids sensor blind zone)
const float FLATTENER_OVERSHOOT_CM = 15.0f;       // Distance between seed hatch and rear flattener so rover drives past last point
const float LEVELER_OVERSHOOT_CM = FLATTENER_OVERSHOOT_CM; // Compatibility alias
const unsigned long TUBE_PUNCH_SETTLE_MS = 0;
const unsigned long TUBE_RETRACT_SETTLE_MS = 0;

const int soilSensorUP = 0;
const int soilSensorDOWN = 150;

// Seed Dispenser Gate Servo Angles
// Gate 1: Calamansi (GPIO 27)
const int gate1DEFAULT = 90; // Default closed
const int gate1OPEN    = 60; // Open hatch

// Gate 2: Sitaw (GPIO 4)
const int gate2DEFAULT = 90; // Default closed
const int gate2OPEN    = 60; // Open hatch

// Gate 3: Peanut (GPIO 23)
const int gate3DEFAULT = 85; // Default closed
const int gate3OPEN    = 55; // Open hatch

// Seed dispenser open duration: 1 second flash move
const unsigned long SEED_DISPENSE_OPEN_MS = 1000;

// Legacy aliases for backward compatibility
const int seedCLOSED = gate1DEFAULT;
const int seedOPEN   = gate1OPEN;

// Rake / Furrow Mechanism Servo Angles (GPIO 26)
const int rakeDEFAULT = 0;   // Default / Raised (retracted)
const int rakeOPEN    = 20;  // Open / Lowered to furrow & rake soil
const int soilMechUP   = rakeDEFAULT;
const int soilMechDOWN = rakeOPEN;
const int levelerUP = 90;
const int levelerDOWN = 140;
const int flattenerUP = 90;
const int flattenerDOWN = 140;
const int molderUP = flattenerUP;
const int molderDOWN = flattenerDOWN;
const int seedTubeUP = 70;      // Retracted / Raised up (during travel)
const int seedTubeDOWN = 150;   // Lowered into soil to punch hole

enum class PlantingState { Idle, CheckingSoil, SurveyingBed, ReturningFromSurvey, LoweringRake, Ready, Planting, ReturningToStart, Paused, Completed, Cancelled, Emergency, Failed, Interrupted };

enum class DropSubState { Idle, LoweringTube, DispensingSeed, RaisingTube };

struct RoverCalibration {
  float secondsPerMeter = 3.5;
  int soilDryRaw = -1;
  int soilWetRaw = -1;
  float rakeToGateCm = 0;
  bool soilCalibrationValid = false;
};

const char *SOIL_CALIBRATION_VERSION = "soil-linear-v1";
// When true, allows automatic planting without waiting for or requiring calibrated soil moisture or soil temperature
bool bypassSoilChecks = true;

struct PlantingSession {
  String sessionId;
  String cropProfile;
  int activeSeedGate = 1; // 1: Calamansi (GPIO 27), 2: Sitaw (GPIO 4), 3: Peanut (GPIO 23)
  String fieldLabel;
  int targetDrops = 0;
  int completedDrops = 0;
  float spacingCm = 0;
  float rowSpacingCm = 0;
  unsigned long gateOpenMs = SEED_DISPENSE_OPEN_MS;
  float rakeOffsetCm = 0;
  float nextDropAtCm = 0;
  unsigned long startedAtMs = 0;
  unsigned long stateChangedAtMs = 0;
  unsigned long lastHeartbeatAtMs = 0;
  bool gateOpen = false;
  unsigned long gateOpenedAtMs = 0;
  int soilRaw = 0;
  bool soilSampleAvailable = false;
  float soilPercent = NAN;
  float soilTemperatureC = NAN;
  float airTemperatureC = NAN;
  float humidityPercent = NAN;
  float frontDistanceCm = NAN;
  float rearDistanceCm = NAN;
  bool frontSensorAvailable = false;
  bool rearSensorAvailable = false;
  bool frontObstacle = false;
  bool rearObstacle = false;
  unsigned long obstacleSampleAtMs = 0;
  unsigned long soilCapturedAtMs = 0;
  unsigned long soilCapturedOffsetMs = 0;
  bool awaitingPhoneAck = false;
  String failureCode;
  float estimatedDistanceCm = 0;
  unsigned long lastDistanceUpdateAtMs = 0;
  bool motorsMoving = false;

  // Drop Station Sub-Sequence Tracking
  DropSubState dropSubState = DropSubState::Idle;
  unsigned long dropSubStateStartedAtMs = 0;

  // Field-End Sensor & Dynamic Station Division
  bool fieldDistanceLocked = false;
  float detectedFieldDistanceCm = 0;
  float plantingStartDistanceCm = 0;

  // Scouting / Bed Survey Tracking (Survey First)
  float surveyDistanceCm = 0;
  float surveyReturnDistanceCm = 0;
  unsigned long lastSurveyReturnUpdateAtMs = 0;

  // Automatic Return to Start Tracking (Automatic Mode)
  float totalForwardDistanceCm = 0;
  float returnDistanceCm = 0;
  unsigned long returnStartedAtMs = 0;
  unsigned long lastReturnUpdateAtMs = 0;
  unsigned long reverseTransitionStartedAtMs = 0;
  bool reversingToolsDeployed = false;
  PlantingState stateBeforePause = PlantingState::Idle;
};

WebServer server(80);
Servo soilSensorServo;
Servo seedServo;          // Seed Gate 1 (Default / Calamansi, GPIO 27)
Servo seedServo2;         // Seed Gate 2 (Sitaw, GPIO 4)
Servo seedServo3;         // Seed Gate 3 (Peanut, GPIO 23)
Servo soilMechanismServo; // Rake mechanism (GPIO 26)
Servo levelerServo;       // Soil leveler mechanism (GPIO 32)
Servo flattenerServo;     // Soil flattener mechanism (GPIO 33 - flattens soil after raking)
#define molderServo flattenerServo
Servo seedTubeServo;      // Hole punch & seed drop tube servo (GPIO 2)
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature temperatureSensor(&oneWire);
DHT dht(DHT_SENSOR_PIN, DHT_SENSOR_TYPE);
Preferences preferences;
RoverCalibration calibration;
PlantingSession planting;
bool rakeCommandedDown = false;
bool levelerCommandedDown = false;
bool flattenerCommandedDown = false;
#define molderCommandedDown flattenerCommandedDown
bool seedTubeCommandedDown = false;
PlantingState plantingState = PlantingState::Idle;
bool plantingSoilPrecheckRequested = false;
bool plantingSoilPrecheckReady = false;
bool soilReferenceCaptureActive = false;
unsigned long soilReferenceCaptureStartedAtMs = 0;

unsigned long lastHealthLog = 0;
unsigned long clientDisconnectedAt = 0;
unsigned long lastSoftApWatchdogCheck = 0;
unsigned long lastWifiAttempt = 0;
unsigned long lastDhtSampleAtMs = 0;
unsigned long lastObstacleSampleAtMs = 0;
bool hadConnectedClient = false;
void savePlantingCheckpoint();

const char *stateName(PlantingState state) {
  switch (state) {
    case PlantingState::Idle: return "IDLE";
    case PlantingState::CheckingSoil: return "CHECKING_SOIL";
    case PlantingState::SurveyingBed: return "SURVEYING_BED";
    case PlantingState::ReturningFromSurvey: return "RETURNING_FROM_SURVEY";
    case PlantingState::LoweringRake: return "LOWERING_RAKE";
    case PlantingState::Ready: return "READY";
    case PlantingState::Planting: return "PLANTING";
    case PlantingState::ReturningToStart: return "RETURNING_TO_START";
    case PlantingState::Paused: return "PAUSED";
    case PlantingState::Completed: return "COMPLETED";
    case PlantingState::Cancelled: return "CANCELLED";
    case PlantingState::Emergency: return "EMERGENCY_STOPPED";
    case PlantingState::Failed: return "FAILED";
    case PlantingState::Interrupted: return "INTERRUPTED";
  }
  return "UNKNOWN";
}

bool hasActivePlantingSession() {
  return plantingState == PlantingState::CheckingSoil ||
         plantingState == PlantingState::SurveyingBed ||
         plantingState == PlantingState::ReturningFromSurvey ||
         plantingState == PlantingState::LoweringRake ||
         plantingState == PlantingState::Ready ||
         plantingState == PlantingState::Planting ||
         plantingState == PlantingState::ReturningToStart ||
         plantingState == PlantingState::Paused;
}

const char *signalQuality(int rssi) {
  if (rssi >= -50) return "excellent";
  if (rssi >= -60) return "good";
  if (rssi >= -70) return "fair";
  return "weak";
}

void stopMotors() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  planting.motorsMoving = false;
}

void moveForward() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  planting.motorsMoving = true;
}

void moveBackward() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  planting.motorsMoving = true;
}

void turnLeft() {
  // Turn Left: Left wheels BACKWARD, Right wheels FORWARD
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  planting.motorsMoving = true;
  Serial.println("[MOTOR] Turn Left (Left BACKWARD, Right FORWARD)");
}

void turnRight() {
  // Turn Right: Left wheels FORWARD, Right wheels BACKWARD
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  planting.motorsMoving = true;
  Serial.println("[MOTOR] Turn Right (Left FORWARD, Right BACKWARD)");
}

int resolveSeedGate(const String &cropProfile, int explicitGate = 0) {
  if (explicitGate >= 1 && explicitGate <= 3) return explicitGate;
  String lower = cropProfile;
  lower.toLowerCase();
  if (lower.indexOf("calamansi") >= 0 || lower == "1" || lower == "gate1" || lower == "gate_1") {
    return 1;
  }
  if (lower.indexOf("sitaw") >= 0 || lower == "2" || lower == "gate2" || lower == "gate_2") {
    return 2;
  }
  if (lower.indexOf("peanut") >= 0 || lower == "3" || lower == "gate3" || lower == "gate_3") {
    return 3;
  }
  return 1;
}

void closeSeedGate() {
  seedServo.write(gate1DEFAULT);
  seedServo2.write(gate2DEFAULT);
  seedServo3.write(gate3DEFAULT);
  planting.gateOpen = false;
}

void openActiveSeedGate() {
  if (planting.activeSeedGate == 2) {
    seedServo2.write(gate2OPEN);
  } else if (planting.activeSeedGate == 3) {
    seedServo3.write(gate3OPEN);
  } else {
    seedServo.write(gate1OPEN);
  }
  planting.gateOpen = true;
}

void setRakeUp() { soilMechanismServo.write(soilMechUP); rakeCommandedDown = false; }
void setRakeDown() { soilMechanismServo.write(soilMechDOWN); rakeCommandedDown = true; }
inline void setLevelerUp() { levelerCommandedDown = false; }
inline void setLevelerDown() { levelerCommandedDown = true; }
void setFlattenerUp() { flattenerServo.write(flattenerUP); flattenerCommandedDown = false; }
void setFlattenerDown() { flattenerServo.write(flattenerDOWN); flattenerCommandedDown = true; }
inline void setMolderUp() { setFlattenerUp(); }
inline void setMolderDown() { setFlattenerDown(); }
inline void setSeedTubeUp() { seedTubeCommandedDown = false; }
inline void setSeedTubeDown() { seedTubeCommandedDown = true; }
void raiseMechanisms() { closeSeedGate(); soilSensorServo.write(soilSensorUP); setRakeUp(); setFlattenerUp(); }
void safeState() { stopMotors(); raiseMechanisms(); }
void setState(PlantingState state) { plantingState = state; planting.stateChangedAtMs = millis(); }

void updateEstimatedDistance(unsigned long now) {
  if ((plantingState != PlantingState::Planting && plantingState != PlantingState::SurveyingBed) || !planting.motorsMoving || calibration.secondsPerMeter <= 0) return;
  if (planting.lastDistanceUpdateAtMs == 0) {
    planting.lastDistanceUpdateAtMs = now;
    return;
  }
  const unsigned long elapsedMs = now - planting.lastDistanceUpdateAtMs;
  planting.estimatedDistanceCm += (elapsedMs / 1000.0f) * (100.0f / calibration.secondsPerMeter);
  planting.totalForwardDistanceCm = planting.estimatedDistanceCm;
  planting.lastDistanceUpdateAtMs = now;
}

void updateSurveyReturnDistance(unsigned long now) {
  if (plantingState != PlantingState::ReturningFromSurvey || !planting.motorsMoving || calibration.secondsPerMeter <= 0) return;
  if (planting.lastSurveyReturnUpdateAtMs == 0) {
    planting.lastSurveyReturnUpdateAtMs = now;
    return;
  }
  const unsigned long elapsedMs = now - planting.lastSurveyReturnUpdateAtMs;
  planting.surveyReturnDistanceCm += (elapsedMs / 1000.0f) * (100.0f / calibration.secondsPerMeter);
  planting.lastSurveyReturnUpdateAtMs = now;
}

void updateReturnDistance(unsigned long now) {
  if (plantingState != PlantingState::ReturningToStart || !planting.motorsMoving || calibration.secondsPerMeter <= 0) return;
  if (planting.lastReturnUpdateAtMs == 0) {
    planting.lastReturnUpdateAtMs = now;
    return;
  }
  const unsigned long elapsedMs = now - planting.lastReturnUpdateAtMs;
  planting.returnDistanceCm += (elapsedMs / 1000.0f) * (100.0f / calibration.secondsPerMeter);
  planting.lastReturnUpdateAtMs = now;
}

void pausePlanting(const char *failureCode = nullptr) {
  updateEstimatedDistance(millis());
  updateSurveyReturnDistance(millis());
  updateReturnDistance(millis());
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  planting.stateBeforePause = plantingState;
  setState(PlantingState::Paused);
  savePlantingCheckpoint();
}

void finishPlanting(PlantingState terminalState, const char *failureCode = nullptr) {
  updateEstimatedDistance(millis());
  updateSurveyReturnDistance(millis());
  updateReturnDistance(millis());
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  setState(terminalState);
  planting.awaitingPhoneAck = true;
  savePlantingCheckpoint();
}

float readUltrasonicDistanceCm(int triggerPin, int echoPin) {
  // Clear trigger pin first
  digitalWrite(triggerPin, LOW);
  delayMicroseconds(4);
  digitalWrite(triggerPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(triggerPin, LOW);

  // 20000 microseconds timeout gives ~340 cm maximum range
  const unsigned long duration = pulseIn(echoPin, HIGH, 20000UL);
  if (duration == 0) return NAN;

  const float dist = (duration * 0.0343f) / 2.0f;
  if (dist < 2.0f || dist > 350.0f) return NAN;
  return dist;
}

void sampleEnvironment(unsigned long now, bool force = false) {
  if (!force && now - lastDhtSampleAtMs < DHT_SAMPLE_INTERVAL_MS) return;
  lastDhtSampleAtMs = now;
  const float humidity = dht.readHumidity();
  const float temperature = dht.readTemperature();
  planting.humidityPercent = isfinite(humidity) && humidity >= 0 && humidity <= 100 ? humidity : NAN;
  planting.airTemperatureC = isfinite(temperature) && temperature >= -40 && temperature <= 80 ? temperature : NAN;
}

void sampleObstacles(unsigned long now, bool force = false) {
  if (!force && now - lastObstacleSampleAtMs < OBSTACLE_SAMPLE_INTERVAL_MS) return;
  lastObstacleSampleAtMs = now;
  planting.obstacleSampleAtMs = now;

  // Sensor 2 (Front): Measures distance to the end of the field / boundary
  const float frontRaw = readUltrasonicDistanceCm(FRONT_ULTRASONIC_TRIG_PIN, FRONT_ULTRASONIC_ECHO_PIN);
  if (isnan(frontRaw)) {
    // Open path ahead (> 200 cm), no obstacle
    planting.frontDistanceCm = 250.0f;
    planting.frontSensorAvailable = true;
    planting.frontObstacle = false;
  } else {
    planting.frontDistanceCm = frontRaw;
    planting.frontSensorAvailable = true;
    if (planting.frontDistanceCm <= 20.0f) {
      planting.frontObstacle = true;
    } else if (planting.frontDistanceCm > 25.0f) {
      planting.frontObstacle = false;
    }
  }

  // Brief 8ms delay prevents acoustic crosstalk into Sensor 1 without stalling WebServer loop
  delay(8);

  // Sensor 1 (Rear / Obstacle): Monitors for obstacles and notifies the app
  const float rearRaw = readUltrasonicDistanceCm(REAR_ULTRASONIC_TRIG_PIN, REAR_ULTRASONIC_ECHO_PIN);
  static int rearDetectCount = 0;
  static int rearClearCount = 0;
  static unsigned long lastObstacleLogMs = 0;

  if (isnan(rearRaw)) {
    // Open path behind (> 200 cm), no obstacle
    planting.rearDistanceCm = 250.0f;
    planting.rearSensorAvailable = true;
    planting.rearObstacle = false;
    rearDetectCount = 0;
    rearClearCount = 0;
  } else {
    planting.rearDistanceCm = rearRaw;
    planting.rearSensorAvailable = true;
    if (planting.rearDistanceCm <= OBSTACLE_WARN_DISTANCE_CM) {
      rearDetectCount++;
      rearClearCount = 0;
      if (rearDetectCount >= 2 && !planting.rearObstacle) {
        planting.rearObstacle = true;
        if (now - lastObstacleLogMs >= 5000) {
          lastObstacleLogMs = now;
          Serial.printf("[OBSTACLE] Rear obstacle detected at %.1f cm\n", planting.rearDistanceCm);
        }
      }
    } else if (planting.rearDistanceCm > OBSTACLE_CLEAR_DISTANCE_CM) {
      rearClearCount++;
      rearDetectCount = 0;
      if (rearClearCount >= 2 && planting.rearObstacle) {
        planting.rearObstacle = false;
      }
    }
  }
}

float calibratedSoilPercent(int raw);

void readSoilSnapshot() {
  planting.soilRaw = analogRead(SOIL_SENSOR_PIN);
  // ADC rail readings indicate an open/short probe input on this board.
  planting.soilSampleAvailable = planting.soilRaw > 0 && planting.soilRaw < 4095;
  planting.soilPercent = calibratedSoilPercent(planting.soilRaw);
  temperatureSensor.requestTemperatures();
  const float value = temperatureSensor.getTempCByIndex(0);
  planting.soilTemperatureC = value == DEVICE_DISCONNECTED_C || value < -55 || value > 125 ? NAN : value;
  sampleEnvironment(millis(), true);

  // If bypass mode is active, substitute safe nominal readings so missing/uncalibrated sensors never block planting
  if (bypassSoilChecks) {
    if (isnan(planting.soilTemperatureC)) {
      planting.soilTemperatureC = isfinite(planting.airTemperatureC) ? planting.airTemperatureC : 28.0f;
    }
    if (isnan(planting.soilPercent)) {
      planting.soilPercent = 55.0f;
      planting.soilSampleAvailable = true;
      if (planting.soilRaw <= 0 || planting.soilRaw >= 4095) planting.soilRaw = 2000;
    }
  }

  planting.soilCapturedAtMs = millis();
  planting.soilCapturedOffsetMs = planting.startedAtMs == 0 ? 0 : planting.soilCapturedAtMs - planting.startedAtMs;
  if (hasActivePlantingSession() || planting.awaitingPhoneAck) {
    savePlantingCheckpoint();
  }
}

float calibratedSoilPercent(int raw) {
  if (!calibration.soilCalibrationValid || calibration.soilDryRaw == calibration.soilWetRaw || raw <= 0 || raw >= 4095) return NAN;
  const float value = 100.0f * (calibration.soilDryRaw - raw) / (calibration.soilDryRaw - calibration.soilWetRaw);
  return constrain(value, 0.0f, 100.0f);
}

void readSensorSnapshot() { readSoilSnapshot(); }

void loadCalibration() {
  preferences.begin("rover-cal", true);
  calibration.secondsPerMeter = preferences.getFloat("sec-per-meter", 3.5f);
  if (isnan(calibration.secondsPerMeter) || calibration.secondsPerMeter < 0.5f) {
    calibration.secondsPerMeter = 3.5f;
  }
  calibration.soilCalibrationValid = preferences.getBool("soil-cal-valid", false);
  calibration.soilDryRaw = preferences.getInt("soil-dry", -1);
  calibration.soilWetRaw = preferences.getInt("soil-wet", -1);
  calibration.soilCalibrationValid = calibration.soilCalibrationValid &&
      calibration.soilDryRaw >= 0 && calibration.soilDryRaw <= 4095 &&
      calibration.soilWetRaw >= 0 && calibration.soilWetRaw <= 4095 &&
      calibration.soilDryRaw != calibration.soilWetRaw;
  calibration.rakeToGateCm = preferences.getFloat("rake-offset", 0.0f);
  if (isnan(calibration.rakeToGateCm)) calibration.rakeToGateCm = 0.0f;
  preferences.end();
}

void saveCalibration() {
  preferences.begin("rover-cal", false);
  preferences.putFloat("sec-per-meter", calibration.secondsPerMeter);
  preferences.putInt("soil-dry", calibration.soilDryRaw);
  preferences.putInt("soil-wet", calibration.soilWetRaw);
  preferences.putBool("soil-cal-valid", calibration.soilCalibrationValid);
  preferences.putFloat("rake-offset", calibration.rakeToGateCm);
  preferences.end();
}

void savePlantingCheckpoint() {
  if (planting.sessionId.isEmpty()) return;
  JsonDocument checkpoint;
  checkpoint["session_id"] = planting.sessionId;
  checkpoint["crop_profile"] = planting.cropProfile;
  checkpoint["active_seed_gate"] = planting.activeSeedGate;
  checkpoint["field_distance_locked"] = planting.fieldDistanceLocked;
  checkpoint["detected_field_distance_cm"] = planting.detectedFieldDistanceCm;
  checkpoint["planting_start_distance_cm"] = planting.plantingStartDistanceCm;
  checkpoint["field_label"] = planting.fieldLabel;
  checkpoint["target_drops"] = planting.targetDrops;
  checkpoint["completed_drops"] = planting.completedDrops;
  checkpoint["spacing_cm"] = planting.spacingCm;
  checkpoint["row_spacing_cm"] = planting.rowSpacingCm;
  checkpoint["gate_open_ms"] = planting.gateOpenMs;
  checkpoint["rake_offset_cm"] = planting.rakeOffsetCm;
  checkpoint["estimated_distance_cm"] = planting.estimatedDistanceCm;
  checkpoint["total_forward_distance_cm"] = planting.totalForwardDistanceCm;
  checkpoint["survey_distance_cm"] = planting.surveyDistanceCm;
  checkpoint["return_distance_cm"] = planting.returnDistanceCm;
  checkpoint["soil_sample_available"] = planting.soilSampleAvailable;
  if (planting.soilSampleAvailable) checkpoint["soil_raw"] = planting.soilRaw;
  if (isfinite(planting.soilPercent)) checkpoint["soil_percent"] = planting.soilPercent;
  if (isfinite(planting.soilTemperatureC)) checkpoint["soil_temperature_c"] = planting.soilTemperatureC;
  if (isfinite(planting.airTemperatureC)) checkpoint["air_temperature_c"] = planting.airTemperatureC;
  if (isfinite(planting.humidityPercent)) checkpoint["humidity_percent"] = planting.humidityPercent;
  checkpoint["soil_captured_at_ms"] = planting.soilCapturedAtMs;
  checkpoint["soil_capture_offset_ms"] = planting.soilCapturedOffsetMs;
  checkpoint["state"] = stateName(plantingState);
  checkpoint["awaiting_phone_ack"] = planting.awaitingPhoneAck;
  String serialized;
  serializeJson(checkpoint, serialized);
  preferences.begin("plant-run", false);
  preferences.putString("checkpoint", serialized);
  preferences.end();
}

void restorePlantingCheckpoint() {
  preferences.begin("plant-run", true);
  const String serialized = preferences.getString("checkpoint", "");
  preferences.end();
  if (serialized.isEmpty()) return;
  JsonDocument checkpoint;
  if (deserializeJson(checkpoint, serialized)) return;
  planting = PlantingSession();
  planting.sessionId = checkpoint["session_id"] | "";
  if (planting.sessionId.isEmpty()) return;
  planting.cropProfile = checkpoint["crop_profile"] | "";
  planting.activeSeedGate = checkpoint["active_seed_gate"] | resolveSeedGate(planting.cropProfile);
  planting.fieldDistanceLocked = checkpoint["field_distance_locked"] | false;
  planting.detectedFieldDistanceCm = checkpoint["detected_field_distance_cm"] | 0.0f;
  planting.plantingStartDistanceCm = checkpoint["planting_start_distance_cm"] | 0.0f;
  planting.fieldLabel = checkpoint["field_label"] | "";
  planting.targetDrops = checkpoint["target_drops"] | 0;
  planting.completedDrops = checkpoint["completed_drops"] | 0;
  planting.spacingCm = checkpoint["spacing_cm"] | 0.0f;
  planting.rowSpacingCm = checkpoint["row_spacing_cm"] | 0.0f;
  planting.gateOpenMs = checkpoint["gate_open_ms"] | 300UL;
  planting.rakeOffsetCm = checkpoint["rake_offset_cm"] | 0.0f;
  planting.estimatedDistanceCm = checkpoint["estimated_distance_cm"] | 0.0f;
  planting.totalForwardDistanceCm = checkpoint["total_forward_distance_cm"] | 0.0f;
  planting.surveyDistanceCm = checkpoint["survey_distance_cm"] | 0.0f;
  planting.returnDistanceCm = checkpoint["return_distance_cm"] | 0.0f;
  planting.soilSampleAvailable = checkpoint["soil_sample_available"] | checkpoint["soil_raw"].is<int>();
  planting.soilRaw = checkpoint["soil_raw"] | 0;
  planting.soilPercent = checkpoint["soil_percent"].is<float>() ? checkpoint["soil_percent"].as<float>() : NAN;
  planting.soilTemperatureC = checkpoint["soil_temperature_c"].is<float>() ? checkpoint["soil_temperature_c"].as<float>() : NAN;
  planting.airTemperatureC = checkpoint["air_temperature_c"].is<float>() ? checkpoint["air_temperature_c"].as<float>() : NAN;
  planting.humidityPercent = checkpoint["humidity_percent"].is<float>() ? checkpoint["humidity_percent"].as<float>() : NAN;
  planting.soilCapturedAtMs = checkpoint["soil_captured_at_ms"] | 0UL;
  planting.soilCapturedOffsetMs = checkpoint["soil_capture_offset_ms"] | 0UL;
  planting.awaitingPhoneAck = true;
  planting.failureCode = "POWER_LOSS_REVIEW_REQUIRED";
  setState(PlantingState::Interrupted);
}

void acknowledgePlantingResult(JsonVariantConst payload, JsonDocument &response) {
  const String acknowledgedSession = payload["session_id"] | "";
  if (planting.sessionId.isEmpty() || acknowledgedSession != planting.sessionId || !planting.awaitingPhoneAck) {
    response["status"] = "not_found";
    response["message"] = "No matching unsaved rover result was found.";
    return;
  }
  preferences.begin("plant-run", false);
  preferences.remove("checkpoint");
  preferences.end();
  planting.awaitingPhoneAck = false;
  response["status"] = "success";
  response["data"]["acknowledged_session_id"] = acknowledgedSession;
}

void addCommonHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type, X-Rover-Token");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
}

void sendJson(int statusCode, JsonDocument &document) {
  String body;
  serializeJson(document, body);
  addCommonHeaders();
  server.send(statusCode, "application/json", body);
}

bool authorizeRequest() {
  if (server.header("X-Rover-Token") == ROVER_TOKEN) {
    if (hasActivePlantingSession()) planting.lastHeartbeatAtMs = millis();
    return true;
  }
  JsonDocument response;
  response["status"] = "failed";
  response["message"] = "Unauthorized";
  sendJson(401, response);
  return false;
}

void addCalibrationJson(JsonObject data) {
  data["seconds_per_meter"] = calibration.secondsPerMeter;
  data["soil_dry_raw"] = calibration.soilDryRaw;
  data["soil_wet_raw"] = calibration.soilWetRaw;
  data["rake_to_gate_cm"] = calibration.rakeToGateCm;
  const bool calValid = calibration.soilCalibrationValid || bypassSoilChecks;
  data["soil_moisture_calibrated"] = calValid;
  data["calibration_version"] = calValid ? SOIL_CALIBRATION_VERSION : nullptr;
  data["timed_movement_ready"] = calibration.secondsPerMeter > 0;
  data["movement_tracking"] = "timed_estimate";
}

void addPlantingStatusJson(JsonObject data) {
  const unsigned long now = millis();
  sampleEnvironment(now);
  sampleObstacles(now);
  updateEstimatedDistance(now);
  updateSurveyReturnDistance(now);
  updateReturnDistance(now);
  data["state"] = stateName(plantingState);
  data["session_id"] = planting.sessionId;
  data["crop_profile"] = planting.cropProfile;
  data["active_seed_gate"] = planting.activeSeedGate;
  data["field_label"] = planting.fieldLabel;
  data["target_drops"] = planting.targetDrops;
  data["completed_drops"] = planting.completedDrops;
  data["distance_cm"] = planting.estimatedDistanceCm;
  data["estimated_distance_cm"] = planting.estimatedDistanceCm;
  data["distance_is_estimated"] = true;
  data["movement_tracking"] = "timed_estimate";
  data["total_forward_distance_cm"] = planting.totalForwardDistanceCm;
  data["survey_distance_cm"] = planting.surveyDistanceCm;
  data["survey_return_distance_cm"] = planting.surveyReturnDistanceCm;
  data["return_distance_cm"] = (plantingState == PlantingState::ReturningFromSurvey) ? planting.surveyReturnDistanceCm : planting.returnDistanceCm;
  data["next_drop_at_cm"] = planting.nextDropAtCm;
  data["gate_open"] = planting.gateOpen;
  data["is_dispensing"] = (planting.dropSubState == DropSubState::DispensingSeed);
  const bool calValid = calibration.soilCalibrationValid || bypassSoilChecks;
  if (planting.soilSampleAvailable) {
    data["soil_raw"] = planting.soilRaw;
  } else if (bypassSoilChecks) {
    data["soil_raw"] = 2000;
  } else {
    data["soil_raw"] = nullptr;
  }
  data["soil_sample_available"] = planting.soilSampleAvailable || bypassSoilChecks;
  if (isfinite(planting.soilPercent)) {
    data["soil_moisture_percent"] = planting.soilPercent;
  } else if (bypassSoilChecks) {
    data["soil_moisture_percent"] = 55.0f;
  } else {
    data["soil_moisture_percent"] = nullptr;
  }
  data["soil_moisture_calibrated"] = calValid;
  data["calibration_version"] = calValid ? SOIL_CALIBRATION_VERSION : nullptr;
  if (isfinite(planting.soilTemperatureC)) {
    data["soil_temperature_c"] = planting.soilTemperatureC;
  } else if (bypassSoilChecks) {
    data["soil_temperature_c"] = 28.0f;
  } else {
    data["soil_temperature_c"] = nullptr;
  }
  if (isfinite(planting.airTemperatureC)) data["air_temperature_c"] = planting.airTemperatureC;
  else data["air_temperature_c"] = nullptr;
  if (isfinite(planting.humidityPercent)) data["humidity_percent"] = planting.humidityPercent;
  else data["humidity_percent"] = nullptr;
  if (planting.frontSensorAvailable) data["front_distance_cm"] = planting.frontDistanceCm;
  else data["front_distance_cm"] = nullptr;
  if (planting.rearSensorAvailable) data["rear_distance_cm"] = planting.rearDistanceCm;
  else data["rear_distance_cm"] = nullptr;
  data["front_obstacle"] = planting.frontObstacle;
  data["rear_obstacle"] = planting.rearObstacle;
  data["obstacle_warning"] = planting.rearObstacle || planting.frontObstacle;
  data["field_distance_cm"] = planting.frontDistanceCm;
  if (planting.frontSensorAvailable) {
    data["field_distance_ft"] = planting.frontDistanceCm / 30.48f;
  } else {
    data["field_distance_ft"] = nullptr;
  }
  data["field_distance_locked"] = planting.fieldDistanceLocked;
  data["detected_field_distance_cm"] = planting.detectedFieldDistanceCm;
  data["calculated_spacing_cm"] = planting.spacingCm;
  data["front_sensor_available"] = planting.frontSensorAvailable;
  data["rear_sensor_available"] = planting.rearSensorAvailable;
  data["obstacle_sample_age_ms"] = millis() - planting.obstacleSampleAtMs;
  data["soil_capture_offset_ms"] = planting.soilCapturedOffsetMs;
  if (planting.soilCapturedAtMs == 0) data["soil_sample_age_ms"] = nullptr;
  else data["soil_sample_age_ms"] = millis() - planting.soilCapturedAtMs;
  if (lastDhtSampleAtMs == 0) data["environment_sample_age_ms"] = nullptr;
  else data["environment_sample_age_ms"] = millis() - lastDhtSampleAtMs;
  data["awaiting_phone_ack"] = planting.awaitingPhoneAck;
  data["rake_commanded_down"] = rakeCommandedDown;
  data["leveler_commanded_down"] = levelerCommandedDown;
  data["flattener_commanded_down"] = flattenerCommandedDown;
  data["molder_commanded_down"] = flattenerCommandedDown;
  data["seed_tube_commanded_down"] = seedTubeCommandedDown;
  data["failure_code"] = planting.failureCode;
  data["firmware_version"] = FIRMWARE_VERSION;
}

void handleHealth() {
  if (!authorizeRequest()) return;
  JsonDocument response;
  response["status"] = "success";
  response["data"]["rover"] = "SeedRover-01";
  response["data"]["transport"] = "local_wifi";
  response["data"]["firmware_version"] = FIRMWARE_VERSION;
  response["data"]["uptime_ms"] = millis();
  response["data"]["planting_state"] = stateName(plantingState);
  sendJson(200, response);
}

void handleSensors() {
  if (!authorizeRequest()) return;
  readSensorSnapshot();
  if (plantingSoilPrecheckRequested) {
    plantingSoilPrecheckRequested = false;
    plantingSoilPrecheckReady = true;
  }
  JsonDocument response;
  response["status"] = "success";
  const bool calValid = calibration.soilCalibrationValid || bypassSoilChecks;
  if (planting.soilSampleAvailable) {
    response["data"]["soil_raw"] = planting.soilRaw;
  } else if (bypassSoilChecks) {
    response["data"]["soil_raw"] = 2000;
  } else {
    response["data"]["soil_raw"] = nullptr;
  }
  response["data"]["soil_sample_available"] = planting.soilSampleAvailable || bypassSoilChecks;
  if (isfinite(planting.soilPercent)) {
    response["data"]["soil_moisture_percent"] = planting.soilPercent;
  } else if (bypassSoilChecks) {
    response["data"]["soil_moisture_percent"] = 55.0f;
  } else {
    response["data"]["soil_moisture_percent"] = nullptr;
  }
  response["data"]["soil_moisture_calibrated"] = calValid;
  response["data"]["calibration_version"] = calValid ? SOIL_CALIBRATION_VERSION : nullptr;
  response["data"]["firmware_version"] = FIRMWARE_VERSION;
  response["data"]["sampled_at_ms"] = millis();
  if (isfinite(planting.soilTemperatureC)) {
    response["data"]["soil_temperature_c"] = planting.soilTemperatureC;
  } else if (bypassSoilChecks) {
    response["data"]["soil_temperature_c"] = 28.0f;
  } else {
    response["data"]["soil_temperature_c"] = nullptr;
  }
  if (isfinite(planting.airTemperatureC)) response["data"]["air_temperature_c"] = planting.airTemperatureC;
  else response["data"]["air_temperature_c"] = nullptr;
  if (isfinite(planting.humidityPercent)) response["data"]["humidity_percent"] = planting.humidityPercent;
  else response["data"]["humidity_percent"] = nullptr;
  sampleObstacles(millis(), true);
  if (planting.frontSensorAvailable) response["data"]["front_distance_cm"] = planting.frontDistanceCm;
  else response["data"]["front_distance_cm"] = nullptr;
  if (planting.rearSensorAvailable) response["data"]["rear_distance_cm"] = planting.rearDistanceCm;
  else response["data"]["rear_distance_cm"] = nullptr;
  response["data"]["front_obstacle"] = planting.frontObstacle;
  response["data"]["rear_obstacle"] = planting.rearObstacle;
  response["data"]["front_sensor_available"] = planting.frontSensorAvailable;
  response["data"]["rear_sensor_available"] = planting.rearSensorAvailable;
  response["data"]["obstacle_sample_age_ms"] = millis() - planting.obstacleSampleAtMs;
  sendJson(200, response);
}

void handlePlantingStatus() {
  if (!authorizeRequest()) return;
  JsonDocument response;
  response["status"] = "success";
  addPlantingStatusJson(response["data"].to<JsonObject>());
  sendJson(200, response);
}

bool parsePositive(JsonVariantConst value, float &target) {
  if (value.isNull()) return false;
  const float parsed = value.as<float>();
  if (parsed <= 0) return false;
  target = parsed;
  return true;
}

void startPlantingRow(JsonVariantConst payload, JsonDocument &response) {
  const String requestedSessionId = payload["session_id"] | "";
  if (!requestedSessionId.isEmpty() && requestedSessionId == planting.sessionId) {
    response["status"] = "success";
    response["data"]["accepted_command"] = "START_PLANTING_ROW";
    response["data"]["state"] = stateName(plantingState);
    response["data"]["duplicate_run"] = true;
    return;
  }
  if (planting.awaitingPhoneAck) {
    // Automatically archive the previous row checkpoint and allow the new row to proceed immediately
    preferences.begin("plant-run", false);
    preferences.remove("checkpoint");
    preferences.end();
    planting.awaitingPhoneAck = false;
  }
  if (hasActivePlantingSession()) {
    response["status"] = "conflict";
    response["message"] = "A planting session is already active";
    return;
  }
  const unsigned long requestedSampleAtMs =
      payload["soil_sampled_at_ms"].as<unsigned long>();
  const int precheckedSoilRaw = planting.soilRaw;
  const float precheckedSoilPercent = planting.soilPercent;
  const float precheckedSoilTemperatureC = planting.soilTemperatureC;
  const unsigned long precheckedAtMs = planting.soilCapturedAtMs;
  plantingSoilPrecheckReady = false;

  // Demo mode: use safe built-in values and never stop the planting flow for
  // missing or over-specific configuration fields from the app.
  String sessionId = requestedSessionId;
  String profile = payload["crop_profile"] | "sitaw";
  if (payload["crop_profile"].isNull() && !payload["seed_type"].isNull()) {
    profile = payload["seed_type"].as<String>();
  }
  int explicitGate = payload["seed_gate"] | (payload["gate"] | 0);
  int activeGate = resolveSeedGate(profile, explicitGate);
  int targetDrops = payload["target_drops"] | 5;
  float spacingCm = payload["spacing_cm"] | 50.0f;
  unsigned long gateOpenMs = payload["gate_open_ms"] | SEED_DISPENSE_OPEN_MS;
  if (sessionId.isEmpty()) sessionId = String("DEMO-") + String(millis());
  if (targetDrops <= 0) targetDrops = 5;
  if (spacingCm <= 0) spacingCm = 50.0f;
  if (gateOpenMs == 0) gateOpenMs = SEED_DISPENSE_OPEN_MS;
  planting = PlantingSession();
  planting.sessionId = sessionId;
  planting.cropProfile = profile;
  planting.activeSeedGate = activeGate;
  planting.fieldLabel = String(payload["field_label"] | "");
  planting.targetDrops = targetDrops;
  planting.spacingCm = spacingCm;
  planting.rowSpacingCm = payload["row_spacing_cm"] | 0;
  planting.gateOpenMs = gateOpenMs;
  planting.rakeOffsetCm = payload["rake_offset_cm"] | calibration.rakeToGateCm;
  if (planting.rakeOffsetCm <= 0) planting.rakeOffsetCm = calibration.rakeToGateCm;

  planting.startedAtMs = millis();
  planting.soilRaw = precheckedSoilRaw;
  planting.soilSampleAvailable = (precheckedSoilRaw > 0);
  planting.soilPercent = precheckedSoilPercent;
  planting.soilTemperatureC = precheckedSoilTemperatureC;
  planting.soilCapturedAtMs = precheckedAtMs;
  planting.soilCapturedOffsetMs = 0;
  planting.lastHeartbeatAtMs = millis();
  sampleObstacles(millis(), true);
  safeState();

  // STEP 1: Before checking distance, the moisture & temperature probe servo
  // goes DOWN into the soil to check moisture and temp and notify the app!
  soilSensorServo.write(soilSensorDOWN);
  setState(PlantingState::CheckingSoil);
  Serial.println("[ROW START] Step 1: Lowering moisture & temperature probe servo into soil...");

  savePlantingCheckpoint();
  response["status"] = "success";
  response["data"]["accepted_command"] = "START_PLANTING_ROW";
  response["data"]["state"] = stateName(plantingState);
  response["data"]["active_seed_gate"] = activeGate;
}

void setCalibration(JsonVariantConst payload, JsonDocument &response) {
  float secondsPerMeter = calibration.secondsPerMeter;
  int soilDryRaw = calibration.soilDryRaw;
  int soilWetRaw = calibration.soilWetRaw;
  float rakeToGateCm = calibration.rakeToGateCm;
  const bool soilCalibrationProvided = !payload["soil_dry_raw"].isNull() || !payload["soil_wet_raw"].isNull();

  if (!payload["seconds_per_meter"].isNull() &&
      (!parsePositive(payload["seconds_per_meter"], secondsPerMeter) || secondsPerMeter > 120.0f)) {
    response["status"] = "invalid_configuration";
    response["message"] = "seconds_per_meter must be greater than 0 and no more than 120";
    return;
  }
  if (!payload["soil_dry_raw"].isNull()) soilDryRaw = payload["soil_dry_raw"].as<int>();
  if (!payload["soil_wet_raw"].isNull()) soilWetRaw = payload["soil_wet_raw"].as<int>();
  if (!payload["rake_to_gate_cm"].isNull()) rakeToGateCm = payload["rake_to_gate_cm"].as<float>();
  if (soilCalibrationProvided &&
      (soilDryRaw < 0 || soilDryRaw > 4095 || soilWetRaw < 0 || soilWetRaw > 4095)) {
    response["status"] = "invalid_configuration";
    response["message"] = "Soil calibration readings must be between 0 and 4095";
    return;
  }
  if (rakeToGateCm < 0 || rakeToGateCm > 200) {
    response["status"] = "invalid_configuration";
    response["message"] = "rake_to_gate_cm must be between 0 and 200";
    return;
  }
  if (soilCalibrationProvided && soilDryRaw == soilWetRaw) {
    response["status"] = "invalid_configuration";
    response["message"] = "Dry and wet soil calibration readings must differ";
    return;
  }
  calibration.secondsPerMeter = secondsPerMeter;
  calibration.soilDryRaw = soilDryRaw;
  calibration.soilWetRaw = soilWetRaw;
  if (soilCalibrationProvided) calibration.soilCalibrationValid = true;
  calibration.rakeToGateCm = rakeToGateCm;
  saveCalibration();
  response["status"] = "success";
  addCalibrationJson(response["data"].to<JsonObject>());
}

void handleCommand() {
  if (!authorizeRequest()) return;
  JsonDocument request;
  if (deserializeJson(request, server.arg("plain"))) {
    JsonDocument response;
    response["status"] = "failed";
    response["message"] = "Invalid JSON";
    sendJson(400, response);
    return;
  }
  const String commandId = request["command_id"] | "";
  const String command = request["command"] | "";
  JsonVariantConst payload = request["payload"];
  JsonDocument response;
  response["command_id"] = commandId;
  response["timestamp"] = millis();
  int statusCode = 200;

  if (command == "PING") {
    response["status"] = "success";
    response["data"]["reply"] = "PONG";
  } else if (command == "GET_PLANTING_STATUS") {
    response["status"] = "success";
    addPlantingStatusJson(response["data"].to<JsonObject>());
  } else if (command == "GET_CALIBRATION") {
    response["status"] = "success";
    addCalibrationJson(response["data"].to<JsonObject>());
  } else if (command == "SET_CALIBRATION") {
    setCalibration(payload, response);
  } else if (command == "START_PLANTING_ROW") {
    startPlantingRow(payload, response);
  } else if (command == "ACK_PLANTING_RESULT") {
    acknowledgePlantingResult(payload, response);
  } else if (command == "MOVE_FORWARD") {
    if (!hasActivePlantingSession()) {
      sampleObstacles(millis(), true);
      moveForward();
      response["status"] = "success";
    } else {
      response["status"] = "movement_locked";
      response["message"] = "Automatic planting controls forward movement; use Stop to interrupt it";
      statusCode = 409;
    }
  } else if (command == "STOP") {
    if (hasActivePlantingSession()) pausePlanting(); else stopMotors();
    response["status"] = "success";
  } else if (command == "PAUSE_PLANTING") {
    if (hasActivePlantingSession()) pausePlanting();
    response["status"] = "success";
  } else if (command == "RESUME_PLANTING") {
    if (plantingState != PlantingState::Paused) {
      response["status"] = "not_paused";
      response["message"] = "Planting session is not paused";
      statusCode = 409;
    } else {
      planting.failureCode = "";
      if (planting.stateBeforePause == PlantingState::SurveyingBed) {
        // Paused during forward raking/scouting pass
        setRakeDown();
        setFlattenerUp();
        closeSeedGate();
        moveForward();
        setState(PlantingState::SurveyingBed);
        planting.lastDistanceUpdateAtMs = millis();
      } else if (planting.stateBeforePause == PlantingState::ReturningFromSurvey) {
        // Paused during return from survey pass
        setRakeUp();
        setFlattenerUp();
        closeSeedGate();
        moveBackward();
        setState(PlantingState::ReturningFromSurvey);
        planting.lastSurveyReturnUpdateAtMs = millis();
      } else if (planting.stateBeforePause == PlantingState::ReturningToStart) {
        // Paused during final return to start pass
        setRakeUp();
        setFlattenerUp();
        closeSeedGate();
        moveBackward();
        setState(PlantingState::ReturningToStart);
        planting.lastReturnUpdateAtMs = millis();
      } else {
        // Paused during forward planting pass: flattener DOWN, rake UP, gate closed
        setRakeUp();
        setFlattenerDown();
        closeSeedGate();
        moveForward();
        setState(PlantingState::Planting);
        planting.lastDistanceUpdateAtMs = millis();
      }
      response["status"] = "success";
    }
  } else if (command == "CANCEL_PLANTING" || command == "STOP_PLANTING") {
    finishPlanting(PlantingState::Cancelled, "OPERATOR_CANCELLED");
    response["status"] = "success";
  } else if (command == "EMERGENCY_STOP") {
    finishPlanting(PlantingState::Emergency, "EMERGENCY_STOP");
    response["status"] = "success";
  } else if (command == "MOVE_BACKWARD" || command == "TURN_LEFT" || command == "TURN_RIGHT") {
    if (hasActivePlantingSession()) {
      pausePlanting("MOVEMENT_LOCKED");
      response["status"] = "movement_locked";
      response["message"] = "Reverse and turning are disabled during a planting row";
      statusCode = 409;
    } else {
      if (command == "MOVE_BACKWARD") {
        sampleObstacles(millis(), true);
        moveBackward();
        response["status"] = "success";
      } else {
        if (command == "TURN_LEFT") turnLeft();
        if (command == "TURN_RIGHT") turnRight();
        response["status"] = "success";
      }
    }
  } else if (command == "CHECK_SOIL") {
    if (hasActivePlantingSession()) {
      response["status"] = "mechanism_locked";
      response["message"] = "Manual soil checks are disabled during automatic planting";
      statusCode = 409;
    } else {
      soilSensorServo.write(soilSensorDOWN);
      response["status"] = "success";
    }
  } else if (command == "PRECHECK_PLANTING_SOIL") {
    if (hasActivePlantingSession()) {
      response["status"] = "mechanism_locked";
      response["message"] = "Planting pre-check is unavailable during an active run";
      statusCode = 409;
    } else {
      stopMotors();
      setRakeUp();
      plantingSoilPrecheckReady = false;
      plantingSoilPrecheckRequested = true;
      soilSensorServo.write(soilSensorDOWN);
      response["status"] = "success";
    }
  } else if (command == "CAPTURE_SOIL_REFERENCE") {
    if (hasActivePlantingSession()) {
      response["status"] = "mechanism_locked";
      response["message"] = "Soil reference capture is unavailable during an active planting run";
      statusCode = 409;
    } else {
      stopMotors();
      setRakeUp();
      plantingSoilPrecheckRequested = false;
      plantingSoilPrecheckReady = false;
      soilReferenceCaptureActive = true;
      soilReferenceCaptureStartedAtMs = millis();
      soilSensorServo.write(soilSensorDOWN);
      response["status"] = "success";
    }
  } else if (command == "CANCEL_SOIL_REFERENCE_CAPTURE") {
    if (!hasActivePlantingSession()) {
      soilReferenceCaptureActive = false;
      soilReferenceCaptureStartedAtMs = 0;
      soilSensorServo.write(soilSensorUP);
      setRakeUp();
      stopMotors();
    }
    response["status"] = "success";
  } else if (command == "CANCEL_PLANTING_PRECHECK") {
    if (!hasActivePlantingSession()) {
      plantingSoilPrecheckRequested = false;
      plantingSoilPrecheckReady = false;
      soilSensorServo.write(soilSensorUP);
      setRakeUp();
      stopMotors();
    }
    response["status"] = "success";
  } else if (command == "SOIL_SENSOR_DOWN" || command == "SOIL_SENSOR_UP" ||
             command == "RAKE_DOWN" || command == "RAKE_UP" ||
             command == "LEVELER_DOWN" || command == "LEVELER_UP" ||
             command == "SOIL_LEVELER_DOWN" || command == "SOIL_LEVELER_UP" ||
             command == "FLATTENER_DOWN" || command == "FLATTENER_UP" ||
             command == "SOIL_FLATTENER_DOWN" || command == "SOIL_FLATTENER_UP" ||
             command == "MOLDER_DOWN" || command == "MOLDER_UP" ||
             command == "SOIL_MOLDER_DOWN" || command == "SOIL_MOLDER_UP" ||
             command == "SEED_TUBE_DOWN" || command == "SEED_TUBE_UP" ||
             command == "HOLE_TUBE_DOWN" || command == "HOLE_TUBE_UP" ||
             command == "SEED_GATE_OPEN" || command == "SEED_GATE_CLOSE" ||
             command == "SEED_GATE_1_OPEN" || command == "SEED_GATE_2_OPEN" || command == "SEED_GATE_3_OPEN") {
    if (hasActivePlantingSession()) {
      response["status"] = "mechanism_locked";
      response["message"] = "Manual mechanism controls are disabled during automatic planting";
      statusCode = 409;
    } else {
      if (command == "SOIL_SENSOR_DOWN") soilSensorServo.write(soilSensorDOWN);
      if (command == "SOIL_SENSOR_UP") soilSensorServo.write(soilSensorUP);
      if (command == "RAKE_DOWN") setRakeDown();
      if (command == "RAKE_UP") setRakeUp();
      if (command == "LEVELER_DOWN" || command == "SOIL_LEVELER_DOWN") setLevelerDown();
      if (command == "LEVELER_UP" || command == "SOIL_LEVELER_UP") setLevelerUp();
      if (command == "FLATTENER_DOWN" || command == "SOIL_FLATTENER_DOWN" ||
          command == "MOLDER_DOWN" || command == "SOIL_MOLDER_DOWN") setFlattenerDown();
      if (command == "FLATTENER_UP" || command == "SOIL_FLATTENER_UP" ||
          command == "MOLDER_UP" || command == "SOIL_MOLDER_UP") setFlattenerUp();
      if (command == "SEED_TUBE_DOWN" || command == "HOLE_TUBE_DOWN") setSeedTubeDown();
      if (command == "SEED_TUBE_UP" || command == "HOLE_TUBE_UP") setSeedTubeUp();
      if (command == "SEED_GATE_OPEN") openActiveSeedGate();
      if (command == "SEED_GATE_CLOSE") closeSeedGate();
      if (command == "SEED_GATE_1_OPEN") seedServo.write(gate1OPEN);
      if (command == "SEED_GATE_2_OPEN") seedServo2.write(gate2OPEN);
      if (command == "SEED_GATE_3_OPEN") seedServo3.write(gate3OPEN);
      response["status"] = "success";
    }
  } else {
    response["status"] = "invalid_command";
    response["message"] = "Unsupported command";
    statusCode = 400;
  }

  if (response["data"].isNull()) response["data"].to<JsonObject>();
  response["data"]["accepted_command"] = command;
  response["data"]["planting_state"] = stateName(plantingState);
  sendJson(statusCode, response);
}

void updatePlantingStateMachine() {
  const unsigned long now = millis();
  sampleEnvironment(now);
  sampleObstacles(now);
  if (soilReferenceCaptureActive &&
      now - soilReferenceCaptureStartedAtMs >= SOIL_REFERENCE_CAPTURE_TIMEOUT_MS) {
    soilReferenceCaptureActive = false;
    soilReferenceCaptureStartedAtMs = 0;
    soilSensorServo.write(soilSensorUP);
    setRakeUp();
    setFlattenerUp();
    stopMotors();
  }
  if (plantingSoilPrecheckReady &&
      now - planting.soilCapturedAtMs > PLANTING_PRECHECK_MAX_AGE_MS) {
    plantingSoilPrecheckReady = false;
  }
  if (plantingState == PlantingState::CheckingSoil && now - planting.stateChangedAtMs >= SOIL_SETTLE_MS) {
    readSensorSnapshot();
    soilSensorServo.write(soilSensorUP);
    Serial.printf("[SOIL CHECK COMPLETE] Moisture: %.1f%% (Raw %d), Temp: %.1f C. Notifying app...\n",
                  planting.soilPercent, planting.soilRaw, planting.soilTemperatureC);

    // =========================================================================
    // STEP 1: RAKING & BED SCOUTING (getting the distance before the wall or getting the cm)
    // 1. Lower Rake to till furrow (GPIO 26 -> rakeOPEN = 20 deg)
    // 2. Raise Soil Flattener UP (GPIO 33 -> flattenerUP = 90 deg)
    // 3. Keep Seed Gates closed
    // 4. Move forward: tilling furrow and measuring distance until wall or target cm
    // =========================================================================
    setRakeDown();
    setFlattenerUp();
    closeSeedGate();

    planting.estimatedDistanceCm = 0;
    planting.totalForwardDistanceCm = 0;
    planting.surveyDistanceCm = 0;
    planting.surveyReturnDistanceCm = 0;
    planting.lastDistanceUpdateAtMs = now;
    planting.lastHeartbeatAtMs = now;

    moveForward();
    setState(PlantingState::SurveyingBed);
    savePlantingCheckpoint();
    Serial.println("[STEP 1: RAKING STARTED] Rake DOWN. Moving forward to till furrow and get distance before wall or target cm...");
    return;
  }

  // =========================================================================
  // STEP 1: BED SCOUTING & RAKING (FORWARD MEASURE & REVERSE TO ORIGIN)
  // Rakes furrow, gets distance before wall (ultrasonic) or target cm
  // =========================================================================
  if (plantingState == PlantingState::SurveyingBed) {
    if (now - planting.lastHeartbeatAtMs > APP_HEARTBEAT_TIMEOUT_MS) {
      pausePlanting("HEARTBEAT_LOSS");
      return;
    }

    updateEstimatedDistance(now);
    sampleObstacles(now);

    const float frontDist = planting.frontDistanceCm;
    bool endOfBedReached = false;
    bool stoppedByWall = false;

    // Target cm from configured drops and spacing
    const float targetCm = (planting.targetDrops > 0 && planting.spacingCm > 0)
        ? (planting.targetDrops * planting.spacingCm)
        : MAX_FIELD_DISTANCE_CM;

    // Check if front sensor detected end boundary/wall (<= FIELD_END_WALL_STOP_CM)
    static int wallDetectCount = 0;
    const bool wallInRange = planting.frontSensorAvailable && frontDist > 2.0f && frontDist <= FIELD_END_WALL_STOP_CM;
    if (wallInRange) {
      wallDetectCount++;
    } else {
      wallDetectCount = 0;
    }

    if (wallDetectCount >= 2) {
      wallDetectCount = 0;
      endOfBedReached = true;
      stoppedByWall = true;
      Serial.printf("[STEP 1: WALL DETECTED] Front wall confirmed at %.1f cm (Traveled: %.1f cm)!\n", frontDist, planting.estimatedDistanceCm);
    } else if (targetCm > 0 && planting.estimatedDistanceCm >= targetCm) {
      wallDetectCount = 0;
      endOfBedReached = true;
      Serial.printf("[STEP 1: TARGET CM REACHED] Target row distance reached: %.1f cm.\n", targetCm);
    } else if (planting.estimatedDistanceCm >= MAX_FIELD_DISTANCE_CM) {
      wallDetectCount = 0;
      endOfBedReached = true;
      Serial.printf("[STEP 1: MAX REACHED] Max field distance reached (%.1f cm).\n", MAX_FIELD_DISTANCE_CM);
    }

    if (endOfBedReached) {
      stopMotors();
      planting.surveyDistanceCm = (planting.estimatedDistanceCm >= 10.0f) ? planting.estimatedDistanceCm : targetCm;
      planting.surveyReturnDistanceCm = 0;
      planting.lastSurveyReturnUpdateAtMs = now;
      planting.detectedFieldDistanceCm = planting.surveyDistanceCm;
      planting.fieldDistanceLocked = true;

      const int points = max(planting.targetDrops, 1);
      // If stopped early by wall before reaching target cm, divide the measured distance evenly
      if (stoppedByWall && planting.surveyDistanceCm < targetCm) {
        planting.spacingCm = planting.surveyDistanceCm / (float)(points + 1);
      }
      planting.plantingStartDistanceCm = 0;
      planting.nextDropAtCm = planting.spacingCm; // First drop is at 1 * spacing

      Serial.printf("[STEP 1 COMPLETE] Field distance locked: %.1f cm. Points: %d spaced every %.2f cm (first drop at %.2f cm).\n",
                    planting.surveyDistanceCm, points, planting.spacingCm, planting.nextDropAtCm);

      // =====================================================================
      // STEP 2: GETTING BACK
      // Lift rake UP so it doesn't drag backward through freshly raked furrow!
      // =====================================================================
      setRakeUp();
      setFlattenerUp();
      closeSeedGate();

      delay(300); // Brief pause before reversing
      moveBackward();
      setState(PlantingState::ReturningFromSurvey);
      savePlantingCheckpoint();
      Serial.printf("[STEP 2: GETTING BACK] Rake UP, flattener UP. Reversing %.1f cm back to original start position...\n", planting.surveyDistanceCm);
    }
    return;
  }

  // =========================================================================
  // STEP 2: GETTING BACK (RETURNING FROM SURVEY TO ORIGINAL POSITION)
  // Reverses back to 0 cm with all tools lifted UP
  // =========================================================================
  if (plantingState == PlantingState::ReturningFromSurvey) {
    if (now - planting.lastHeartbeatAtMs > APP_HEARTBEAT_TIMEOUT_MS) {
      pausePlanting("HEARTBEAT_LOSS");
      return;
    }

    // Keep tools raised while reversing
    setRakeUp();
    setFlattenerUp();
    closeSeedGate();

    if (!planting.motorsMoving) {
      moveBackward();
      planting.lastSurveyReturnUpdateAtMs = now;
    }

    updateSurveyReturnDistance(now);

    // Rover returns to exact starting line (0 cm)
    if (planting.surveyReturnDistanceCm >= planting.surveyDistanceCm) {
      stopMotors();
      planting.estimatedDistanceCm = 0;
      planting.totalForwardDistanceCm = 0;
      planting.lastDistanceUpdateAtMs = 0;
      planting.completedDrops = 0;
      planting.dropSubState = DropSubState::Idle;
      planting.nextDropAtCm = planting.spacingCm;

      Serial.printf("[ORIGINAL POSITION REACHED] Rover returned to origin (reversed %.1f cm of %.1f cm).\n",
                    planting.surveyReturnDistanceCm, planting.surveyDistanceCm);

      // =====================================================================
      // STEP 3: PLANTING WITH FLATTENER
      // Rover is at original position:
      // - Rake stays UP (0 deg) - soil already raked in Step 1!
      // - Flattener goes DOWN (140 deg) - flattens & covers soil behind seeds
      // =====================================================================
      setRakeUp();
      setFlattenerDown();
      closeSeedGate();

      Serial.println("[STEP 3: PLANTING PREP] Rake UP (0 deg). Soil Flattener DOWN (140 deg).");
      Serial.printf("[STEP 3: PLANTING] Starting planting pass with flattener DOWN! First seed at %.1f cm.\n", planting.nextDropAtCm);

      setState(PlantingState::LoweringRake);
      savePlantingCheckpoint();
    }
    return;
  }

  if (plantingState == PlantingState::LoweringRake && now - planting.stateChangedAtMs >= RAKE_SETTLE_MS) {
    moveForward();
    setState(PlantingState::Planting);
    planting.lastDistanceUpdateAtMs = now;
    planting.lastHeartbeatAtMs = now;
    Serial.println("[STEP 3: PLANTING STARTED] Moving forward with flattener DOWN to plant seeds and flatten soil...");
    return;
  }

  // =========================================================================
  // STEP 4: GETTING BACK TO ORIGINAL POSITION
  // After planting is done, flattener is raised UP and rover returns to origin (0 cm).
  // =========================================================================
  if (plantingState == PlantingState::ReturningToStart) {
    if (now - planting.lastHeartbeatAtMs > APP_HEARTBEAT_TIMEOUT_MS) {
      pausePlanting("HEARTBEAT_LOSS");
      return;
    }

    // Ensure all tools are lifted UP while reversing back so nothing drags on the planted furrow
    setFlattenerUp();
    setRakeUp();
    closeSeedGate();

    // Start moving backward if not already moving
    if (!planting.motorsMoving) {
      moveBackward();
      planting.lastReturnUpdateAtMs = now;
    }

    updateReturnDistance(now);

    // Rover returns automatically to the exact starting line
    if (planting.returnDistanceCm >= planting.totalForwardDistanceCm) {
      stopMotors();
      setFlattenerUp();
      setRakeUp();
      safeState();
      Serial.printf("[AUTO COMPLETE] Rover reached exact starting position (returned %.1f cm of %.1f cm). Row complete!\n",
                    planting.returnDistanceCm, planting.totalForwardDistanceCm);
      finishPlanting(PlantingState::Completed);
    }
    return;
  }

  if (plantingState != PlantingState::Planting) return;

  if (now - planting.lastHeartbeatAtMs > APP_HEARTBEAT_TIMEOUT_MS) {
    pausePlanting("HEARTBEAT_LOSS");
    return;
  }

  sampleObstacles(now);
  updateEstimatedDistance(now);
  const float distanceCm = planting.estimatedDistanceCm;

  // =========================================================================
  // SEED PLANTING STATION SEQUENCE (Direct Hatch Flash Dispense):
  // 1. Rover stops at station
  // 2. Seed container hatch opens directly (flash move: 1.0s)
  // 3. Seed drops into raked bed
  // 4. Seed container hatch fast closes
  // 5. Rover resumes forward movement with flattener DOWN flattening soil with seeds
  // =========================================================================
  if (planting.dropSubState != DropSubState::Idle) {
    const unsigned long elapsedInSubState = now - planting.dropSubStateStartedAtMs;

    if (planting.dropSubState == DropSubState::DispensingSeed) {
      if (elapsedInSubState >= planting.gateOpenMs) {
        // Seed dropped: fast close seed container gate
        closeSeedGate();
        planting.completedDrops++;
        planting.dropSubState = DropSubState::Idle;
        planting.nextDropAtCm = (planting.completedDrops + 1) * planting.spacingCm;
        savePlantingCheckpoint();
        Serial.printf("[STATION %d/%d COMPLETE] Gate closed. Resuming forward drive with flattener DOWN to cover raked soil with seeds...\n",
                      planting.completedDrops, planting.targetDrops);

        // Resume moving forward with flattener DOWN to flatten soil
        moveForward();
        planting.lastDistanceUpdateAtMs = now;
      }
      return;
    }
    return;
  }

  // =========================================================================
  // DYNAMIC PER-POINT NAVIGATION (ANY ROW LENGTH):
  // Drives forward and dispenses seeds at each configured spacing interval.
  // Next drop at: (completedDrops + 1) * spacingCm.
  // Works for arbitrary distances (from 1 meter to 50+ meters) without hardcoded limits.
  // =========================================================================
  if (planting.completedDrops < planting.targetDrops) {
    if (planting.detectedFieldDistanceCm <= 0) {
      planting.detectedFieldDistanceCm = (planting.targetDrops * planting.spacingCm) + FLATTENER_OVERSHOOT_CM;
      planting.fieldDistanceLocked = true;
    }

    const int nextDropIndex = planting.completedDrops + 1;
    const float targetDropDistFromStart = nextDropIndex * planting.spacingCm;
    planting.nextDropAtCm = targetDropDistFromStart;

    // Trigger station when rover has traveled to this seed position
    if (distanceCm >= targetDropDistFromStart) {
      stopMotors();
      planting.estimatedDistanceCm = targetDropDistFromStart;
      planting.totalForwardDistanceCm = targetDropDistFromStart;

      openActiveSeedGate();
      planting.dropSubState = DropSubState::DispensingSeed;
      planting.dropSubStateStartedAtMs = now;

      Serial.printf("[STATION %d/%d REACHED] Reached %.1f cm (Target: %.1f cm). Dispensing seed from Gate %d for %lu ms...\n",
                    nextDropIndex, planting.targetDrops, distanceCm, targetDropDistFromStart, planting.activeSeedGate, planting.gateOpenMs);
      return;
    }
  }

  // =========================================================================
  // END OF PLANTING & STEP 4: GETTING BACK TO ORIGINAL POSITION
  // All planting points completed: rover continues forward with flattener DOWN
  // to cover the last seed, then raises flattener UP and returns to start (0 cm).
  // =========================================================================
  if (planting.completedDrops >= planting.targetDrops) {
    // Ensure rover keeps moving forward with flattener DOWN until reaching the end of the field distance
    if (!planting.motorsMoving && planting.dropSubState == DropSubState::Idle) {
      moveForward();
      planting.lastDistanceUpdateAtMs = now;
      Serial.println("[FIELD ADVANCE] All seeds dropped. Rover flattening soil over final seeds...");
    }

    sampleObstacles(now);
    const float currentFrontDist = planting.frontDistanceCm;
    static int frontWallHitCount = 0;
    // Front obstacle safety: ignore ground echoes near start; require 3 consecutive hits
    if (planting.frontSensorAvailable && currentFrontDist > 2.0f && currentFrontDist <= FIELD_END_WALL_STOP_CM && distanceCm >= (planting.spacingCm * 0.7f)) {
      frontWallHitCount++;
    } else {
      frontWallHitCount = 0;
    }
    const bool frontWallReached = (frontWallHitCount >= 3);
    const float targetRowEndCm = (planting.surveyDistanceCm > 0)
        ? planting.surveyDistanceCm
        : ((planting.targetDrops * planting.spacingCm) + FLATTENER_OVERSHOOT_CM);
    const bool distanceEndReached = (distanceCm >= targetRowEndCm);

    if (frontWallReached || distanceEndReached) {
      stopMotors();
      frontWallHitCount = 0;
      planting.totalForwardDistanceCm = distanceCm;

      Serial.printf("[PLANTING FINISHED] Planted %d/%d seeds. Total forward: %.1f cm (%.2f m).\n",
                    planting.completedDrops, planting.targetDrops,
                    planting.totalForwardDistanceCm, planting.totalForwardDistanceCm / 100.0f);
      Serial.println("[STEP 4: GETTING BACK] Raising flattener to default UP. Rover returning to original starting position...");

      // When planting is done: flattener goes UP and rake stays UP
      setFlattenerUp();
      setRakeUp();
      closeSeedGate();

      // Begin returning to original starting position
      planting.returnDistanceCm = 0;
      planting.lastReturnUpdateAtMs = now;
      planting.returnStartedAtMs = now;
      setState(PlantingState::ReturningToStart);
      savePlantingCheckpoint();

      delay(300); // Brief pause before reversing
      moveBackward();
      return;
    }
  }
}

void handleOptions() { addCommonHeaders(); server.send(204); }

int staRetryAttempts = 0;
const int MAX_STA_RETRIES = 2;

void connectToWifi() {
  const IPAddress roverAddress(192, 168, 4, 1);
  const IPAddress gateway(192, 168, 4, 1);
  const IPAddress subnet(255, 255, 255, 0);
  const IPAddress dhcpLeaseStart(192, 168, 4, 10);

  // AP+STA: start the SeedRover-01 hotspot FIRST and keep it online
  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(false);
  // Reserves 192.168.4.2 to 192.168.4.9 for static devices like the ESP32-CAM
  WiFi.softAPConfig(roverAddress, gateway, subnet, dhcpLeaseStart);
  if (!WiFi.softAP("SeedRover-01", ROVER_TOKEN, 1, 0, 4)) {
    Serial.println("SoftAP failed to start. ROVER_TOKEN must be 8-63 characters.");
  } else {
    WiFi.setTxPower(WIFI_POWER_17dBm);
    Serial.println("SeedRover Wi-Fi AP started");
    Serial.println("  Hotspot: SeedRover-01 (Channel 1)");
    Serial.print("  AP address: http://");
    Serial.println(WiFi.softAPIP());
    Serial.println("  DHCP pool starts at 192.168.4.10 (192.168.4.2 reserved for ESP32-CAM)");
  }

  // Attempt initial STA connection once at boot
  if (strlen(WIFI_SSID) > 0) {
    Serial.printf("  Initiating boot connection to router '%s'...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }
}

void reconnectToWifi(const char *reason) {
  Serial.print("Wi-Fi recovery: ");
  Serial.println(reason);
  if (hasActivePlantingSession()) pausePlanting("WIFI_CONNECTION_LOSS");
}

void monitorRoverWifi() {
  // In the field, WIFI_SSID won't exist. Stop scanning after MAX_STA_RETRIES
  // so the SoftAP radio NEVER channel-hops and clients never drop!
  if (strlen(WIFI_SSID) > 0 && WiFi.status() != WL_CONNECTED && staRetryAttempts < MAX_STA_RETRIES) {
    if (millis() - lastWifiAttempt > 15000) {
      lastWifiAttempt = millis();
      staRetryAttempts++;
      Serial.printf("STA retry %d/%d to router '%s'...\n", staRetryAttempts, MAX_STA_RETRIES, WIFI_SSID);
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      if (staRetryAttempts >= MAX_STA_RETRIES) {
        Serial.println("STA router unavailable. Holding pure SoftAP on Channel 1 to preserve client stability.");
      }
    }
  }
}

void printConnectedDeviceSignal() {
  const int rssi = WiFi.RSSI();
  Serial.printf(" | Wi-Fi signal: %d dBm (%s)", rssi, signalQuality(rssi));
}

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("\n==========================================");
  Serial.println("       SeedRover ESP32 Firmware Boot       ");
  Serial.println("==========================================");

  // Put the H-bridge in its stopped state before the radio starts or any
  // request can arrive. This avoids leaving motor inputs floating during boot.
  Serial.println("[BOOT] 1. Initializing Motor Pins...");
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);

  Serial.println("[BOOT] 2. Configuring Wi-Fi...");
  connectToWifi();

  Serial.println("[BOOT] 3. Loading Calibration & Checkpoints...");
  loadCalibration();
  restorePlantingCheckpoint();

  Serial.println("[BOOT] 4. Starting Web Server...");
  const char *headers[] = {"X-Rover-Token"};
  server.collectHeaders(headers, 1);
  server.on("/health", HTTP_GET, handleHealth);
  server.on("/health", HTTP_OPTIONS, handleOptions);
  server.on("/sensors", HTTP_GET, handleSensors);
  server.on("/sensors", HTTP_OPTIONS, handleOptions);
  server.on("/planting-status", HTTP_GET, handlePlantingStatus);
  server.on("/planting-status", HTTP_OPTIONS, handleOptions);
  server.on("/command", HTTP_POST, handleCommand);
  server.on("/command", HTTP_OPTIONS, handleOptions);
  server.onNotFound([]() {
    JsonDocument response;
    response["status"] = "failed";
    response["message"] = "Not found";
    sendJson(404, response);
  });
  server.begin();

  Serial.println("[BOOT] 5. Initializing Sensors...");
  pinMode(SOIL_SENSOR_PIN, INPUT);
  pinMode(FRONT_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(FRONT_ULTRASONIC_ECHO_PIN, INPUT);
  pinMode(REAR_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(REAR_ULTRASONIC_ECHO_PIN, INPUT);
  digitalWrite(FRONT_ULTRASONIC_TRIG_PIN, LOW);
  digitalWrite(REAR_ULTRASONIC_TRIG_PIN, LOW);
  temperatureSensor.begin();
  dht.begin();

  Serial.println("[BOOT] 6. Attaching Servos...");
  soilSensorServo.setPeriodHertz(50);
  seedServo.setPeriodHertz(50);
  seedServo2.setPeriodHertz(50);
  seedServo3.setPeriodHertz(50);
  soilMechanismServo.setPeriodHertz(50);
  flattenerServo.setPeriodHertz(50);

  soilSensorServo.attach(SERVO_SOIL_SENSOR_PIN, 500, 2400);
  seedServo.attach(SERVO_SEED_1_PIN, 500, 2400);
  seedServo2.attach(SERVO_SEED_2_PIN, 500, 2400);
  seedServo3.attach(SERVO_SEED_3_PIN, 500, 2400);
  soilMechanismServo.attach(SERVO_SOIL_MECH_PIN, 500, 2400);
  flattenerServo.attach(SERVO_FLATTENER_PIN, 500, 2400);
  // Note: Leveler (GPIO 32) and Seed Tube (GPIO 2) removed from robot

  safeState();
  sampleEnvironment(millis(), true);
  sampleObstacles(millis(), true);

  Serial.println("[BOOT] 7. Boot Complete!");
  Serial.printf("SeedRover %s ready at http://%s\n", FIRMWARE_VERSION, WiFi.softAPIP().toString().c_str());
  Serial.println("\n[BENCH TEST] Type 'help' or '1', '2', '3', 't', 'drop1', 'soil', 'cal' in Serial Monitor!");
}

void printSerialHelp() {
  Serial.println("\n============================================");
  Serial.println("     SeedRover Firmware Serial Test Menu    ");
  Serial.println("============================================");
  Serial.println(" [1] / [gate1] : Test Gate 1 (Calamansi, GPIO 27)");
  Serial.println(" [2] / [gate2] : Test Gate 2 (Sitaw, GPIO 4)");
  Serial.println(" [3] / [gate3] : Test Gate 3 (Peanut, GPIO 23)");
  Serial.println(" [c] / [close] : Close all seed gates");
  Serial.println(" [drop1]       : Station drop test with Gate 1 (1.0s flash move)");
  Serial.println(" [drop2]       : Station drop test with Gate 2 (1.0s flash move)");
  Serial.println(" [drop3]       : Station drop test with Gate 3 (1.0s flash move)");
  Serial.println(" [rake]        : Toggle rake mechanism (GPIO 26)");
  Serial.println(" [flattener]   : Toggle soil flattener after rake (GPIO 33)");
  Serial.println(" [soil]        : Test soil probe deploy & read (GPIO 13)");
  Serial.println(" [cal]         : View current soil calibration status");
  Serial.println(" [cal dry]     : Set current soil reading as DRY reference (0%)");
  Serial.println(" [cal wet]     : Set current soil reading as WET reference (100%)");
  Serial.println(" [cal D W]     : Manually set references (e.g. 'cal 2626 1300')");
  Serial.println(" [plant]        : Start automatic planting row (bypasses soil checks)");
  Serial.println(" [plant 1/2/3]  : Start automatic planting row with Gate 1, 2, or 3");
  Serial.println(" [speed <sec>]  : Set seconds per meter (e.g. 'speed 10.0')");
  Serial.println(" [bypass]       : Toggle soil check bypass mode");
  Serial.println(" [dist]        : Read Front & Rear ultrasonic distances");
  Serial.println(" [fwd]         : Test motors Forward");
  Serial.println(" [rev]         : Test motors Backward");
  Serial.println(" [left]        : Test Turn Left (Left Backward, Right Forward)");
  Serial.println(" [right]       : Test Turn Right (Left Forward, Right Backward)");
  Serial.println(" [stop]        : Stop all motors");
  Serial.println(" [help]        : Show this menu");
  Serial.println("============================================");
}

void handleSerialCommands() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.isEmpty()) return;

  if (line == "left" || line == "turnleft") {
    turnLeft();
  } else if (line == "right" || line == "turnright") {
    turnRight();
  } else if (line == "fwd" || line == "forward") {
    moveForward();
    Serial.println("[MOTOR] Moving Forward");
  } else if (line == "rev" || line == "back" || line == "backward") {
    moveBackward();
    Serial.println("[MOTOR] Moving Backward");
  } else if (line == "stop" || line == "s") {
    stopMotors();
    Serial.println("[MOTOR] Motors Stopped");
  } else if (line == "1" || line == "gate1") {
    Serial.printf("[TEST] Flash Opening Gate 1 (GPIO 27 - Calamansi: %d deg -> %d deg) for 1s...\n", gate1DEFAULT, gate1OPEN);
    seedServo.write(gate1OPEN);
    delay(SEED_DISPENSE_OPEN_MS);
    seedServo.write(gate1DEFAULT);
    Serial.printf("[TEST] Gate 1 CLOSED to %d deg.\n", gate1DEFAULT);
  } else if (line == "2" || line == "gate2") {
    Serial.printf("[TEST] Flash Opening Gate 2 (GPIO 4 - Sitaw: %d deg -> %d deg) for 1s...\n", gate2DEFAULT, gate2OPEN);
    seedServo2.write(gate2OPEN);
    delay(SEED_DISPENSE_OPEN_MS);
    seedServo2.write(gate2DEFAULT);
    Serial.printf("[TEST] Gate 2 CLOSED to %d deg.\n", gate2DEFAULT);
  } else if (line == "3" || line == "gate3") {
    Serial.printf("[TEST] Flash Opening Gate 3 (GPIO 23 - Peanut: %d deg -> %d deg) for 1s...\n", gate3DEFAULT, gate3OPEN);
    seedServo3.write(gate3OPEN);
    delay(SEED_DISPENSE_OPEN_MS);
    seedServo3.write(gate3DEFAULT);
    Serial.printf("[TEST] Gate 3 CLOSED to %d deg.\n", gate3DEFAULT);
  } else if (line == "c" || line == "close") {
    Serial.println("[TEST] Closing all gates...");
    closeSeedGate();
  } else if (line == "drop1" || line == "drop2" || line == "drop3") {
    int g = (line == "drop2") ? 2 : (line == "drop3" ? 3 : 1);
    Serial.printf("[TEST] Running station drop sequence for Gate %d (1.0s flash move)...\n", g);
    Serial.printf("  Opening Gate %d...\n", g);
    if (g == 2) seedServo2.write(gate2OPEN);
    else if (g == 3) seedServo3.write(gate3OPEN);
    else seedServo.write(gate1OPEN);
    delay(SEED_DISPENSE_OPEN_MS);
    Serial.println("  Closing seed gate...");
    closeSeedGate();
    Serial.println("[TEST] Station drop sequence finished!");
  } else if (line == "rake") {
    if (rakeCommandedDown) {
      setRakeUp();
      Serial.println("[TEST] Rake UP.");
    } else {
      setRakeDown();
      Serial.println("[TEST] Rake DOWN.");
    }
  } else if (line == "leveler") {
    Serial.println("[TEST] Leveler is retired/removed from robot.");
  } else if (line == "flattener" || line == "flat" || line == "molder") {
    if (flattenerCommandedDown) {
      setFlattenerUp();
      Serial.println("[TEST] Soil Flattener UP.");
    } else {
      setFlattenerDown();
      Serial.println("[TEST] Soil Flattener DOWN (flattening raked soil).");
    }
  } else if (line == "soil") {
    Serial.println("[TEST] Lowering soil probe...");
    soilSensorServo.write(soilSensorDOWN);
    delay(1200);
    readSensorSnapshot();
    soilSensorServo.write(soilSensorUP);
    if (calibration.soilCalibrationValid && isfinite(planting.soilPercent)) {
      Serial.printf("[TEST] Soil Raw: %d (%.1f%% Moisture) | Temp: %.1f C\n",
                    planting.soilRaw, planting.soilPercent, planting.soilTemperatureC);
    } else {
      Serial.printf("[TEST] Soil Raw: %d (Uncalibrated) | Temp: %.1f C\n",
                    planting.soilRaw, planting.soilTemperatureC);
      Serial.println("  --> [HINT] Type 'cal dry' in air, then 'cal wet' in water/wet soil to calibrate moisture.");
    }
    if (isnan(planting.soilTemperatureC)) {
      Serial.println("  --> [HINT] Soil Temp is 'nan'. Ensure DS18B20 data wire has a 4.7k pull-up resistor to 3.3V on GPIO 14.");
    }
  } else if (line.startsWith("cal")) {
    int currentRaw = analogRead(SOIL_SENSOR_PIN);
    if (line == "cal dry" || line == "cal-dry") {
      calibration.soilDryRaw = currentRaw;
      if (calibration.soilWetRaw > 0 && calibration.soilWetRaw < 4095 && calibration.soilDryRaw != calibration.soilWetRaw) {
        calibration.soilCalibrationValid = true;
      }
      saveCalibration();
      Serial.printf("\n[CALIBRATION] Captured DRY reference: %d (0%% moisture point).\n", calibration.soilDryRaw);
      Serial.printf("  Current Wet Reference: %d | Status: %s\n",
                    calibration.soilWetRaw, calibration.soilCalibrationValid ? "VALID & ACTIVE" : "AWAITING WET REFERENCE");
      if (calibration.soilCalibrationValid) {
        Serial.printf("  Calibration active! Current sensor reading: %.1f%% moisture.\n", calibratedSoilPercent(currentRaw));
      } else {
        Serial.println("  Next: Dip probe in water or wet soil and type 'cal wet'.");
      }
    } else if (line == "cal wet" || line == "cal-wet") {
      calibration.soilWetRaw = currentRaw;
      if (calibration.soilDryRaw > 0 && calibration.soilDryRaw < 4095 && calibration.soilDryRaw != calibration.soilWetRaw) {
        calibration.soilCalibrationValid = true;
      }
      saveCalibration();
      Serial.printf("\n[CALIBRATION] Captured WET reference: %d (100%% moisture point).\n", calibration.soilWetRaw);
      Serial.printf("  Current Dry Reference: %d | Status: %s\n",
                    calibration.soilDryRaw, calibration.soilCalibrationValid ? "VALID & ACTIVE" : "AWAITING DRY REFERENCE");
      if (calibration.soilCalibrationValid) {
        Serial.printf("  Calibration active! Current sensor reading: %.1f%% moisture.\n", calibratedSoilPercent(currentRaw));
      } else {
        Serial.println("  Next: Hold probe in dry air and type 'cal dry'.");
      }
    } else if (line.indexOf(' ') > 0) {
      int firstSpace = line.indexOf(' ');
      int secondSpace = line.indexOf(' ', firstSpace + 1);
      if (secondSpace > 0) {
        int d = line.substring(firstSpace + 1, secondSpace).toInt();
        int w = line.substring(secondSpace + 1).toInt();
        if (d > 0 && d < 4095 && w > 0 && w < 4095 && d != w) {
          calibration.soilDryRaw = d;
          calibration.soilWetRaw = w;
          calibration.soilCalibrationValid = true;
          saveCalibration();
          Serial.printf("\n[CALIBRATION] Saved manual references -> Dry: %d | Wet: %d (Locked to flash!)\n", d, w);
          Serial.printf("  Current sensor raw %d = %.1f%% moisture.\n", currentRaw, calibratedSoilPercent(currentRaw));
        } else {
          Serial.println("[CALIBRATION ERROR] Readings must be between 1 and 4094 and not equal. Example: 'cal 2626 1300'");
        }
      } else {
        Serial.println("[CALIBRATION] Usage: 'cal dry', 'cal wet', or 'cal <dry_raw> <wet_raw>'");
      }
    } else {
      Serial.println("\n============================================");
      Serial.println("        Soil Moisture Calibration Status     ");
      Serial.println("============================================");
      Serial.printf("  Dry Raw Reference (0%%):    %d\n", calibration.soilDryRaw);
      Serial.printf("  Wet Raw Reference (100%%):  %d\n", calibration.soilWetRaw);
      Serial.printf("  Calibration Valid:         %s\n", calibration.soilCalibrationValid ? "YES" : "NO");
      Serial.printf("  Live Raw Reading:          %d\n", currentRaw);
      if (calibration.soilCalibrationValid) {
        Serial.printf("  Calculated Moisture:       %.1f%%\n", calibratedSoilPercent(currentRaw));
      } else {
        Serial.println("  Calculated Moisture:       UNAVAILABLE (Needs calibration)");
      }
      Serial.println("--------------------------------------------");
      Serial.println("  To calibrate:");
      Serial.println("    1. Hold probe in air and type: 'cal dry'");
      Serial.println("    2. Dip tip in water and type:  'cal wet'");
      Serial.println("    Or manually set: 'cal 2626 1300'");
      Serial.println("============================================");
    }
  } else if (line == "dist" || line == "ultra" || line == "sensors") {
    sampleObstacles(millis(), true);
    Serial.printf("[ULTRASONIC TEST]\n  Front Sensor 2 (Boundary/Field): %s (%.1f cm)\n  Rear Sensor 1 (Obstacle Alert):  %s (%.1f cm)\n",
                  planting.frontSensorAvailable ? "DETECTED" : "CLEAR/OUT_OF_RANGE",
                  planting.frontDistanceCm,
                  planting.rearSensorAvailable ? "DETECTED" : "CLEAR/OUT_OF_RANGE",
                  planting.rearDistanceCm);
  } else if (line == "plant" || line.startsWith("plant") || line == "start") {
    int gate = 1;
    int drops = 5;
    if (line == "plant2") gate = 2;
    else if (line == "plant3") gate = 3;
    else if (line.indexOf(' ') > 0) {
      int sp = line.indexOf(' ');
      gate = line.substring(sp + 1).toInt();
      if (gate < 1 || gate > 3) gate = 1;
    }
    Serial.printf("\n[AUTO PLANTING] Starting automatic planting row with Gate %d (%d drops)...\n",
                  gate, drops);
    Serial.println("  --> Bypassing soil moisture and soil temperature checks!");
    JsonDocument dummyReq;
    dummyReq["session_id"] = String("SERIAL-") + String(millis());
    dummyReq["crop_profile"] = gate == 2 ? "sitaw" : (gate == 3 ? "peanut" : "calamansi");
    dummyReq["seed_gate"] = gate;
    dummyReq["target_drops"] = drops;
    dummyReq["spacing_cm"] = 25.0f;
    dummyReq["field_label"] = "Bench Test Row";
    JsonDocument resp;
    startPlantingRow(dummyReq.as<JsonVariantConst>(), resp);
    Serial.println("  --> Row started! Rover will scout/lock field end and plant seeds.");
  } else if (line.startsWith("bypass")) {
    if (line == "bypass on" || line == "bypass 1") {
      bypassSoilChecks = true;
      Serial.println("[BYPASS] Soil moisture & temperature bypass ENABLED.");
    } else if (line == "bypass off" || line == "bypass 0") {
      bypassSoilChecks = false;
      Serial.println("[BYPASS] Soil moisture & temperature bypass DISABLED.");
    } else {
      bypassSoilChecks = !bypassSoilChecks;
      Serial.printf("[BYPASS] Soil moisture & temperature bypass is now: %s\n",
                    bypassSoilChecks ? "ENABLED (Will plant anyway!)" : "DISABLED (Requires sensors)");
    }
  } else if (line.startsWith("speed")) {
    int sp = line.indexOf(' ');
    if (sp > 0) {
      float s = line.substring(sp + 1).toFloat();
      if (s >= 1.0f && s <= 60.0f) {
        calibration.secondsPerMeter = s;
        saveCalibration();
        Serial.printf("[SPEED] Calibrated to %.1f seconds per meter!\n", s);
        Serial.printf("  Over 4 feet (122 cm), a 20 cm spacing will take %.1f seconds drive time.\n",
                      (20.0f / 100.0f) * s);
      } else {
        Serial.println("[SPEED ERROR] Value must be between 1.0 and 60.0. Example: 'speed 10.0'");
      }
    } else {
      Serial.printf("[SPEED] Current calibration: %.1f seconds/meter. Usage: 'speed 10.0'\n", calibration.secondsPerMeter);
    }
  } else if (line == "help" || line == "?") {
    printSerialHelp();
  } else {
    Serial.printf("Unknown command '%s'. Type 'help' for available commands.\n", line.c_str());
  }
}

void loop() {
  server.handleClient();
  handleSerialCommands();
  updatePlantingStateMachine();
  monitorRoverWifi();
  if (millis() - lastHealthLog >= 10000) {
    lastHealthLog = millis();
    Serial.printf("AP: %s (%d clients) | STA: %s | planting: %s\n",
                  WiFi.softAPIP().toString().c_str(), WiFi.softAPgetStationNum(),
                  WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString().c_str() : "disconnected",
                  stateName(plantingState));
  }
  delay(2);
}
