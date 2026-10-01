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

#define SOIL_SENSOR_PIN 34
#define TEMP_SENSOR_PIN 14
#define DHT_SENSOR_PIN 25
#define DHT_SENSOR_TYPE DHT11
// The physical front/rear ultrasonic modules were exchanged; these GPIOs now
// match the rover's actual sensor positions.
#define FRONT_ULTRASONIC_TRIG_PIN 5
#define FRONT_ULTRASONIC_ECHO_PIN 15
#define REAR_ULTRASONIC_TRIG_PIN 16
#define REAR_ULTRASONIC_ECHO_PIN 17
#define SERVO_SOIL_SENSOR_PIN 13
#define SERVO_SEED_PIN 27
#define SERVO_SOIL_MECH_PIN 26
#define IN1 18
#define IN2 19
#define IN3 21
#define IN4 22

const char *FIRMWARE_VERSION = "2.6.0-soil-reference-calibration";
const unsigned long SOFTAP_RESTART_DELAY_MS = 5000;
const unsigned long SOFTAP_WATCHDOG_INTERVAL_MS = 2000;
const unsigned long APP_HEARTBEAT_TIMEOUT_MS = 1800;
const unsigned long SOIL_SETTLE_MS = 1000;
const unsigned long PLANTING_PRECHECK_MAX_AGE_MS = 60000;
const unsigned long SOIL_REFERENCE_CAPTURE_TIMEOUT_MS = 10000;
const unsigned long RAKE_SETTLE_MS = 700;
const unsigned long DHT_SAMPLE_INTERVAL_MS = 2500;
const unsigned long OBSTACLE_SAMPLE_INTERVAL_MS = 120;
const float OBSTACLE_WARN_DISTANCE_CM = 30.0f;
const float OBSTACLE_CLEAR_DISTANCE_CM = 35.0f;
const unsigned long OBSTACLE_STALE_AFTER_MS = 3000;

const int soilSensorUP = 70;
const int soilSensorDOWN = 150;
const int seedCLOSED = 150;
const int seedOPEN = 90;
const int soilMechUP = 90;
const int soilMechDOWN = 140;

enum class PlantingState { Idle, CheckingSoil, LoweringRake, Ready, Planting, Paused, Completed, Cancelled, Emergency, Failed, Interrupted };

struct RoverCalibration {
  float secondsPerMeter = 1.9;
  int soilDryRaw = -1;
  int soilWetRaw = -1;
  float rakeToGateCm = 0;
  bool soilCalibrationValid = false;
};

const char *SOIL_CALIBRATION_VERSION = "soil-linear-v1";

struct PlantingSession {
  String sessionId;
  String cropProfile;
  String fieldLabel;
  int targetDrops = 0;
  int completedDrops = 0;
  float spacingCm = 0;
  float rowSpacingCm = 0;
  unsigned long gateOpenMs = 300;
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
};

WebServer server(80);
Servo soilSensorServo;
Servo seedServo;
Servo soilMechanismServo;
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature temperatureSensor(&oneWire);
DHT dht(DHT_SENSOR_PIN, DHT_SENSOR_TYPE);
Preferences preferences;
RoverCalibration calibration;
PlantingSession planting;
bool rakeCommandedDown = false;
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
    case PlantingState::LoweringRake: return "LOWERING_RAKE";
    case PlantingState::Ready: return "READY";
    case PlantingState::Planting: return "PLANTING";
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
  return plantingState == PlantingState::CheckingSoil || plantingState == PlantingState::LoweringRake ||
         plantingState == PlantingState::Ready || plantingState == PlantingState::Planting ||
         plantingState == PlantingState::Paused;
}

const char *signalQuality(int rssi) {
  if (rssi >= -50) return "excellent";
  if (rssi >= -60) return "good";
  if (rssi >= -70) return "fair";
  return "weak";
}

void stopMotors() { digitalWrite(IN1, LOW); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, LOW); planting.motorsMoving = false; }
void moveForward() { digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); planting.motorsMoving = true; }
void moveBackward() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); planting.motorsMoving = false; }
void turnLeft() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); planting.motorsMoving = false; }
void turnRight() { digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); planting.motorsMoving = false; }

void closeSeedGate() { seedServo.write(seedCLOSED); planting.gateOpen = false; }
void setRakeUp() { soilMechanismServo.write(soilMechUP); rakeCommandedDown = false; }
void setRakeDown() { soilMechanismServo.write(soilMechDOWN); rakeCommandedDown = true; }
void raiseMechanisms() { closeSeedGate(); soilSensorServo.write(soilSensorUP); setRakeUp(); }
void safeState() { stopMotors(); raiseMechanisms(); }
void setState(PlantingState state) { plantingState = state; planting.stateChangedAtMs = millis(); }

void updateEstimatedDistance(unsigned long now) {
  if (plantingState != PlantingState::Planting || !planting.motorsMoving || calibration.secondsPerMeter <= 0) return;
  if (planting.lastDistanceUpdateAtMs == 0) {
    planting.lastDistanceUpdateAtMs = now;
    return;
  }
  const unsigned long elapsedMs = now - planting.lastDistanceUpdateAtMs;
  planting.estimatedDistanceCm += (elapsedMs / 1000.0f) * (100.0f / calibration.secondsPerMeter);
  planting.lastDistanceUpdateAtMs = now;
}

void pausePlanting(const char *failureCode = nullptr) {
  updateEstimatedDistance(millis());
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  setState(PlantingState::Paused);
  savePlantingCheckpoint();
}

void finishPlanting(PlantingState terminalState, const char *failureCode = nullptr) {
  updateEstimatedDistance(millis());
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  setState(terminalState);
  planting.awaitingPhoneAck = true;
  savePlantingCheckpoint();
}

float readUltrasonicDistanceCm(int triggerPin, int echoPin) {
  digitalWrite(triggerPin, LOW);
  delayMicroseconds(3);
  digitalWrite(triggerPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(triggerPin, LOW);
  const unsigned long duration = pulseIn(echoPin, HIGH, 18000UL);
  if (duration == 0) return NAN;
  return duration * 0.0343f / 2.0f;
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
  planting.frontDistanceCm = readUltrasonicDistanceCm(FRONT_ULTRASONIC_TRIG_PIN, FRONT_ULTRASONIC_ECHO_PIN);
  planting.frontSensorAvailable = isfinite(planting.frontDistanceCm);
  if (planting.frontSensorAvailable) {
    if (!planting.frontObstacle && planting.frontDistanceCm <= OBSTACLE_WARN_DISTANCE_CM) planting.frontObstacle = true;
    else if (planting.frontObstacle && planting.frontDistanceCm > OBSTACLE_CLEAR_DISTANCE_CM) planting.frontObstacle = false;
  }
  delayMicroseconds(250);
  planting.rearDistanceCm = readUltrasonicDistanceCm(REAR_ULTRASONIC_TRIG_PIN, REAR_ULTRASONIC_ECHO_PIN);
  planting.rearSensorAvailable = isfinite(planting.rearDistanceCm);
  if (planting.rearSensorAvailable) {
    if (!planting.rearObstacle && planting.rearDistanceCm <= OBSTACLE_WARN_DISTANCE_CM) planting.rearObstacle = true;
    else if (planting.rearObstacle && planting.rearDistanceCm > OBSTACLE_CLEAR_DISTANCE_CM) planting.rearObstacle = false;
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
  calibration.secondsPerMeter = preferences.getFloat("sec-per-meter", 1.9);
  if (calibration.secondsPerMeter <= 0) calibration.secondsPerMeter = 1.9;
  calibration.soilCalibrationValid = preferences.getBool("soil-cal-valid", false);
  calibration.soilDryRaw = preferences.getInt("soil-dry", -1);
  calibration.soilWetRaw = preferences.getInt("soil-wet", -1);
  calibration.soilCalibrationValid = calibration.soilCalibrationValid &&
      calibration.soilDryRaw >= 0 && calibration.soilDryRaw <= 4095 &&
      calibration.soilWetRaw >= 0 && calibration.soilWetRaw <= 4095 &&
      calibration.soilDryRaw != calibration.soilWetRaw;
  calibration.rakeToGateCm = preferences.getFloat("rake-offset", 0);
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
  checkpoint["field_label"] = planting.fieldLabel;
  checkpoint["target_drops"] = planting.targetDrops;
  checkpoint["completed_drops"] = planting.completedDrops;
  checkpoint["spacing_cm"] = planting.spacingCm;
  checkpoint["row_spacing_cm"] = planting.rowSpacingCm;
  checkpoint["gate_open_ms"] = planting.gateOpenMs;
  checkpoint["rake_offset_cm"] = planting.rakeOffsetCm;
  checkpoint["estimated_distance_cm"] = planting.estimatedDistanceCm;
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
  planting.fieldLabel = checkpoint["field_label"] | "";
  planting.targetDrops = checkpoint["target_drops"] | 0;
  planting.completedDrops = checkpoint["completed_drops"] | 0;
  planting.spacingCm = checkpoint["spacing_cm"] | 0.0f;
  planting.rowSpacingCm = checkpoint["row_spacing_cm"] | 0.0f;
  planting.gateOpenMs = checkpoint["gate_open_ms"] | 300UL;
  planting.rakeOffsetCm = checkpoint["rake_offset_cm"] | 0.0f;
  planting.estimatedDistanceCm = checkpoint["estimated_distance_cm"] | 0.0f;
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
  data["soil_moisture_calibrated"] = calibration.soilCalibrationValid;
  data["calibration_version"] = calibration.soilCalibrationValid ? SOIL_CALIBRATION_VERSION : nullptr;
  data["timed_movement_ready"] = calibration.secondsPerMeter > 0;
  data["movement_tracking"] = "timed_estimate";
}

void addPlantingStatusJson(JsonObject data) {
  const unsigned long now = millis();
  sampleEnvironment(now);
  sampleObstacles(now);
  updateEstimatedDistance(now);
  data["state"] = stateName(plantingState);
  data["session_id"] = planting.sessionId;
  data["crop_profile"] = planting.cropProfile;
  data["field_label"] = planting.fieldLabel;
  data["target_drops"] = planting.targetDrops;
  data["completed_drops"] = planting.completedDrops;
  data["distance_cm"] = planting.estimatedDistanceCm;
  data["estimated_distance_cm"] = planting.estimatedDistanceCm;
  data["distance_is_estimated"] = true;
  data["movement_tracking"] = "timed_estimate";
  if (planting.soilSampleAvailable) data["soil_raw"] = planting.soilRaw;
  else data["soil_raw"] = nullptr;
  data["soil_sample_available"] = planting.soilSampleAvailable;
  if (isfinite(planting.soilPercent)) data["soil_moisture_percent"] = planting.soilPercent;
  else data["soil_moisture_percent"] = nullptr;
  data["soil_moisture_calibrated"] = calibration.soilCalibrationValid;
  data["calibration_version"] = calibration.soilCalibrationValid ? SOIL_CALIBRATION_VERSION : nullptr;
  if (isfinite(planting.soilTemperatureC)) data["soil_temperature_c"] = planting.soilTemperatureC;
  else data["soil_temperature_c"] = nullptr;
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
  if (planting.soilSampleAvailable) response["data"]["soil_raw"] = planting.soilRaw;
  else response["data"]["soil_raw"] = nullptr;
  response["data"]["soil_sample_available"] = planting.soilSampleAvailable;
  if (isfinite(planting.soilPercent)) response["data"]["soil_moisture_percent"] = planting.soilPercent;
  else response["data"]["soil_moisture_percent"] = nullptr;
  response["data"]["soil_moisture_calibrated"] = calibration.soilCalibrationValid;
  response["data"]["calibration_version"] = calibration.soilCalibrationValid ? SOIL_CALIBRATION_VERSION : nullptr;
  response["data"]["firmware_version"] = FIRMWARE_VERSION;
  response["data"]["sampled_at_ms"] = millis();
  if (isfinite(planting.soilTemperatureC)) response["data"]["soil_temperature_c"] = planting.soilTemperatureC;
  else response["data"]["soil_temperature_c"] = nullptr;
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
    response["status"] = "result_not_acknowledged";
    response["message"] = "Save or review the previous row result before starting another row.";
    return;
  }
  if (hasActivePlantingSession()) {
    response["status"] = "conflict";
    response["message"] = "A planting session is already active";
    return;
  }
  const unsigned long precheckAge = millis() - planting.soilCapturedAtMs;
  const unsigned long requestedSampleAtMs =
      payload["soil_sampled_at_ms"].as<unsigned long>();
  if (!plantingSoilPrecheckReady || planting.soilCapturedAtMs == 0 ||
      requestedSampleAtMs != planting.soilCapturedAtMs ||
      precheckAge > PLANTING_PRECHECK_MAX_AGE_MS ||
      !planting.soilSampleAvailable || !calibration.soilCalibrationValid ||
      !isfinite(planting.soilPercent) || !isfinite(planting.soilTemperatureC)) {
    plantingSoilPrecheckReady = false;
    response["status"] = "soil_precheck_required";
    response["message"] = "A fresh calibrated moisture and soil-temperature pre-check is required before planting.";
    return;
  }
  const int precheckedSoilRaw = planting.soilRaw;
  const float precheckedSoilPercent = planting.soilPercent;
  const float precheckedSoilTemperatureC = planting.soilTemperatureC;
  const unsigned long precheckedAtMs = planting.soilCapturedAtMs;
  plantingSoilPrecheckReady = false;
  // Demo mode: use safe built-in values and never stop the planting flow for
  // missing or over-specific configuration fields from the app.
  String sessionId = requestedSessionId;
  String profile = payload["crop_profile"] | "sitaw";
  int targetDrops = payload["target_drops"] | 5;
  float spacingCm = payload["spacing_cm"] | 50.0f;
  unsigned long gateOpenMs = payload["gate_open_ms"] | 300UL;
  if (sessionId.isEmpty()) sessionId = String("DEMO-") + String(millis());
  if (targetDrops <= 0) targetDrops = 5;
  if (spacingCm <= 0) spacingCm = 50.0f;
  if (gateOpenMs == 0) gateOpenMs = 300;
  planting = PlantingSession();
  planting.sessionId = sessionId;
  planting.cropProfile = profile;
  planting.fieldLabel = String(payload["field_label"] | "");
  planting.targetDrops = targetDrops;
  planting.spacingCm = spacingCm;
  planting.rowSpacingCm = payload["row_spacing_cm"] | 0;
  planting.gateOpenMs = gateOpenMs;
  planting.rakeOffsetCm = payload["rake_offset_cm"] | calibration.rakeToGateCm;
  if (planting.rakeOffsetCm <= 0) planting.rakeOffsetCm = calibration.rakeToGateCm;
  planting.nextDropAtCm = max(planting.rakeOffsetCm, 0.0f);
  planting.startedAtMs = millis();
  planting.soilRaw = precheckedSoilRaw;
  planting.soilSampleAvailable = true;
  planting.soilPercent = precheckedSoilPercent;
  planting.soilTemperatureC = precheckedSoilTemperatureC;
  planting.soilCapturedAtMs = precheckedAtMs;
  planting.soilCapturedOffsetMs = 0;
  planting.lastHeartbeatAtMs = millis();
  sampleObstacles(millis(), true);
  safeState();
  setRakeDown();
  setState(PlantingState::LoweringRake);
  savePlantingCheckpoint();
  response["status"] = "success";
  response["data"]["accepted_command"] = "START_PLANTING_ROW";
  response["data"]["state"] = stateName(plantingState);
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
      setRakeDown();
      setState(PlantingState::LoweringRake);
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
             command == "RAKE_DOWN" || command == "RAKE_UP") {
    if (hasActivePlantingSession()) {
      response["status"] = "mechanism_locked";
      response["message"] = "Manual mechanism controls are disabled during automatic planting";
      statusCode = 409;
    } else {
      if (command == "SOIL_SENSOR_DOWN") soilSensorServo.write(soilSensorDOWN);
      if (command == "SOIL_SENSOR_UP") soilSensorServo.write(soilSensorUP);
      if (command == "RAKE_DOWN") setRakeDown();
      if (command == "RAKE_UP") setRakeUp();
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
    stopMotors();
  }
  if (plantingSoilPrecheckReady &&
      now - planting.soilCapturedAtMs > PLANTING_PRECHECK_MAX_AGE_MS) {
    plantingSoilPrecheckReady = false;
  }
  if (plantingState == PlantingState::CheckingSoil && now - planting.stateChangedAtMs >= SOIL_SETTLE_MS) {
    readSensorSnapshot();
    soilSensorServo.write(soilSensorUP);
    setRakeDown();
    setState(PlantingState::LoweringRake);
    return;
  }
  if (plantingState == PlantingState::LoweringRake && now - planting.stateChangedAtMs >= RAKE_SETTLE_MS) {
    moveForward();
    setState(PlantingState::Planting);
    planting.lastDistanceUpdateAtMs = now;
    planting.lastHeartbeatAtMs = now;
    return;
  }
  if (plantingState != PlantingState::Planting) return;
  if (now - planting.lastHeartbeatAtMs > APP_HEARTBEAT_TIMEOUT_MS) {
    pausePlanting("HEARTBEAT_LOSS");
    return;
  }
  updateEstimatedDistance(now);
  const float distanceCm = planting.estimatedDistanceCm;
  if (planting.gateOpen) {
    if (now - planting.gateOpenedAtMs >= planting.gateOpenMs) {
      closeSeedGate();
      planting.completedDrops++;
      savePlantingCheckpoint();
      planting.nextDropAtCm += planting.spacingCm;
      if (planting.completedDrops >= planting.targetDrops) {
        finishPlanting(PlantingState::Completed);
      } else {
        moveForward();
        planting.lastDistanceUpdateAtMs = now;
      }
    }
    return;
  }
  if (distanceCm >= planting.nextDropAtCm && planting.completedDrops < planting.targetDrops) {
    stopMotors();
    seedServo.write(seedOPEN);
    planting.gateOpen = true;
    planting.gateOpenedAtMs = now;
  }
}

void handleOptions() { addCommonHeaders(); server.send(204); }

void connectToWifi() {
  const IPAddress roverAddress(192, 168, 4, 1);
  const IPAddress gateway(192, 168, 4, 1);
  const IPAddress subnet(255, 255, 255, 0);
  // Keep the phone's DHCP leases away from the ESP32-CAM at 192.168.4.2.
  const IPAddress dhcpLeaseStart(192, 168, 4, 10);

  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);
  WiFi.softAPConfig(roverAddress, gateway, subnet, dhcpLeaseStart);
  if (!WiFi.softAP("SeedRover-01", ROVER_TOKEN)) {
    Serial.println("SoftAP failed to start. ROVER_TOKEN must be 8-63 characters.");
    return;
  }
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  Serial.println("SeedRover Wi-Fi started");
  Serial.println("Network name: SeedRover-01");
  Serial.println("Wi-Fi password: use the same value as ROVER_TOKEN");
  Serial.print("ESP32 address: http://");
  Serial.println(WiFi.softAPIP());
}

void reconnectToWifi(const char *reason) {
  Serial.print("Wi-Fi recovery: ");
  Serial.println(reason);
  if (hasActivePlantingSession()) pausePlanting("WIFI_CONNECTION_LOSS");
  WiFi.disconnect();
  delay(150);
  connectToWifi();
}

void monitorRoverWifi() {
  // Keep the demo access point stable. Do not restart it while a phone or
  // camera is attempting to associate.
}

void printConnectedDeviceSignal() {
  const int rssi = WiFi.RSSI();
  Serial.printf(" | Wi-Fi signal: %d dBm (%s)", rssi, signalQuality(rssi));
}

void setup() {
  Serial.begin(115200);

  // Put the H-bridge in its stopped state before the radio starts or any
  // request can arrive. This avoids leaving motor inputs floating during boot.
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);

  connectToWifi();
  loadCalibration();
  restorePlantingCheckpoint();
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

  pinMode(SOIL_SENSOR_PIN, INPUT);
  pinMode(FRONT_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(FRONT_ULTRASONIC_ECHO_PIN, INPUT);
  pinMode(REAR_ULTRASONIC_TRIG_PIN, OUTPUT);
  pinMode(REAR_ULTRASONIC_ECHO_PIN, INPUT);
  digitalWrite(FRONT_ULTRASONIC_TRIG_PIN, LOW);
  digitalWrite(REAR_ULTRASONIC_TRIG_PIN, LOW);
  temperatureSensor.begin();
  dht.begin();
  soilSensorServo.setPeriodHertz(50); seedServo.setPeriodHertz(50); soilMechanismServo.setPeriodHertz(50);
  soilSensorServo.attach(SERVO_SOIL_SENSOR_PIN, 500, 2400);
  seedServo.attach(SERVO_SEED_PIN, 500, 2400);
  soilMechanismServo.attach(SERVO_SOIL_MECH_PIN, 500, 2400);
  safeState();
  sampleEnvironment(millis(), true);
  sampleObstacles(millis(), true);
  Serial.printf("SeedRover %s ready at http://%s\n", FIRMWARE_VERSION, WiFi.softAPIP().toString().c_str());
}

void loop() {
  server.handleClient();
  updatePlantingStateMachine();
  monitorRoverWifi();
  if (millis() - lastHealthLog >= 10000) {
    lastHealthLog = millis();
    Serial.printf("Access point active | IP: %s | clients: %d | planting: %s",
                  WiFi.softAPIP().toString().c_str(), WiFi.softAPgetStationNum(), stateName(plantingState));
    Serial.println();
  }
  delay(2);
}
