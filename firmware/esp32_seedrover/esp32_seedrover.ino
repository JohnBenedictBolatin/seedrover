#include <ArduinoJson.h>
#include <WebServer.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <ESP32Servo.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Preferences.h>
#include "HX711.h"

#include "secrets.h"

#define SOIL_SENSOR_PIN 34
#define TEMP_SENSOR_PIN 14
#define HX711_DT 23
#define HX711_SCK 4
#define SERVO_SOIL_SENSOR_PIN 13
#define SERVO_SEED_PIN 27
#define SERVO_SOIL_MECH_PIN 26
#define IN1 18
#define IN2 19
#define IN3 21
#define IN4 22
#define LEFT_ENCODER_PIN 32
#define RIGHT_ENCODER_PIN 33

const char *FIRMWARE_VERSION = "2.0.0-planting";
const unsigned long SOFTAP_RESTART_DELAY_MS = 5000;
const unsigned long SOFTAP_WATCHDOG_INTERVAL_MS = 2000;
const unsigned long FORWARD_HEARTBEAT_TIMEOUT_MS = 1800;
const unsigned long SOIL_SETTLE_MS = 1000;
const unsigned long RAKE_SETTLE_MS = 700;

const int soilSensorUP = 70;
const int soilSensorDOWN = 150;
const int seedCLOSED = 120;
const int seedOPEN = 90;
const int soilMechUP = 90;
const int soilMechDOWN = 130;

enum class PlantingState { Idle, CheckingSoil, LoweringRake, Ready, Planting, Paused, Completed, Cancelled, Emergency, Failed };

struct RoverCalibration {
  float leftTicksPerMeter = 0;
  float rightTicksPerMeter = 0;
  int soilDryRaw = 3200;
  int soilWetRaw = 1300;
  float rakeToGateCm = 0;
};

struct PlantingSession {
  String sessionId;
  String cropProfile;
  String fieldLabel;
  int targetDrops = 0;
  int completedDrops = 0;
  float spacingCm = 0;
  float rowSpacingCm = 0;
  unsigned long gateOpenMs = 450;
  float rakeOffsetCm = 0;
  float nextDropAtCm = 0;
  unsigned long startedAtMs = 0;
  unsigned long stateChangedAtMs = 0;
  unsigned long lastHeartbeatAtMs = 0;
  bool gateOpen = false;
  unsigned long gateOpenedAtMs = 0;
  int soilRaw = 0;
  float soilPercent = 0;
  float temperatureC = 0;
  long seedLoadRaw = 0;
  String failureCode;
  float lastProgressCm = 0;
  unsigned long lastProgressAtMs = 0;
};

WebServer server(80);
Servo soilSensorServo;
Servo seedServo;
Servo soilMechanismServo;
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature temperatureSensor(&oneWire);
HX711 scale;
Preferences preferences;
RoverCalibration calibration;
PlantingSession planting;
PlantingState plantingState = PlantingState::Idle;

volatile uint32_t leftEncoderTicks = 0;
volatile uint32_t rightEncoderTicks = 0;
unsigned long lastHealthLog = 0;
unsigned long clientDisconnectedAt = 0;
unsigned long lastSoftApWatchdogCheck = 0;
bool hadConnectedClient = false;

void IRAM_ATTR onLeftEncoderTick() { leftEncoderTicks++; }
void IRAM_ATTR onRightEncoderTick() { rightEncoderTicks++; }

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

void stopMotors() { digitalWrite(IN1, LOW); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, LOW); }
void moveForward() { digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); }
void moveBackward() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); }
void turnLeft() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); }
void turnRight() { digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); }

void closeSeedGate() { seedServo.write(seedCLOSED); planting.gateOpen = false; }
void raiseMechanisms() { closeSeedGate(); soilSensorServo.write(soilSensorUP); soilMechanismServo.write(soilMechUP); }
void safeState() { stopMotors(); raiseMechanisms(); }
void setState(PlantingState state) { plantingState = state; planting.stateChangedAtMs = millis(); }

void pausePlanting(const char *failureCode = nullptr) {
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  setState(PlantingState::Paused);
}

void finishPlanting(PlantingState terminalState, const char *failureCode = nullptr) {
  safeState();
  if (failureCode != nullptr) planting.failureCode = failureCode;
  setState(terminalState);
}

float calibratedSoilPercent(int raw) {
  if (calibration.soilDryRaw == calibration.soilWetRaw) return 0;
  const float value = 100.0f * (calibration.soilDryRaw - raw) / (calibration.soilDryRaw - calibration.soilWetRaw);
  return constrain(value, 0.0f, 100.0f);
}

float measuredDistanceCm() {
  noInterrupts();
  const uint32_t left = leftEncoderTicks;
  const uint32_t right = rightEncoderTicks;
  interrupts();
  if (calibration.leftTicksPerMeter <= 0 || calibration.rightTicksPerMeter <= 0) return 0;
  const float leftCm = (left / calibration.leftTicksPerMeter) * 100.0f;
  const float rightCm = (right / calibration.rightTicksPerMeter) * 100.0f;
  return (leftCm + rightCm) / 2.0f;
}

void resetEncoderTicks() {
  noInterrupts();
  leftEncoderTicks = 0;
  rightEncoderTicks = 0;
  interrupts();
}

void readSensorSnapshot() {
  planting.soilRaw = analogRead(SOIL_SENSOR_PIN);
  planting.soilPercent = calibratedSoilPercent(planting.soilRaw);
  temperatureSensor.requestTemperatures();
  const float value = temperatureSensor.getTempCByIndex(0);
  planting.temperatureC = value == DEVICE_DISCONNECTED_C ? 0 : value;
  planting.seedLoadRaw = scale.is_ready() ? scale.read_average(3) : 0;
}

void loadCalibration() {
  preferences.begin("rover-cal", true);
  calibration.leftTicksPerMeter = preferences.getFloat("left-tpm", 0);
  calibration.rightTicksPerMeter = preferences.getFloat("right-tpm", 0);
  calibration.soilDryRaw = preferences.getInt("soil-dry", 3200);
  calibration.soilWetRaw = preferences.getInt("soil-wet", 1300);
  calibration.rakeToGateCm = preferences.getFloat("rake-offset", 0);
  preferences.end();
}

void saveCalibration() {
  preferences.begin("rover-cal", false);
  preferences.putFloat("left-tpm", calibration.leftTicksPerMeter);
  preferences.putFloat("right-tpm", calibration.rightTicksPerMeter);
  preferences.putInt("soil-dry", calibration.soilDryRaw);
  preferences.putInt("soil-wet", calibration.soilWetRaw);
  preferences.putFloat("rake-offset", calibration.rakeToGateCm);
  preferences.end();
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
  if (server.header("X-Rover-Token") == ROVER_TOKEN) return true;
  JsonDocument response;
  response["status"] = "failed";
  response["message"] = "Unauthorized";
  sendJson(401, response);
  return false;
}

void addCalibrationJson(JsonObject data) {
  data["left_ticks_per_meter"] = calibration.leftTicksPerMeter;
  data["right_ticks_per_meter"] = calibration.rightTicksPerMeter;
  data["soil_dry_raw"] = calibration.soilDryRaw;
  data["soil_wet_raw"] = calibration.soilWetRaw;
  data["rake_to_gate_cm"] = calibration.rakeToGateCm;
  data["encoder_ready"] = calibration.leftTicksPerMeter > 0 && calibration.rightTicksPerMeter > 0;
}

void addPlantingStatusJson(JsonObject data) {
  noInterrupts();
  const uint32_t left = leftEncoderTicks;
  const uint32_t right = rightEncoderTicks;
  interrupts();
  data["state"] = stateName(plantingState);
  data["session_id"] = planting.sessionId;
  data["crop_profile"] = planting.cropProfile;
  data["field_label"] = planting.fieldLabel;
  data["target_drops"] = planting.targetDrops;
  data["completed_drops"] = planting.completedDrops;
  data["encoder_distance_cm"] = measuredDistanceCm();
  data["left_encoder_ticks"] = left;
  data["right_encoder_ticks"] = right;
  data["soil_raw"] = planting.soilRaw;
  data["soil_moisture_percent"] = planting.soilPercent;
  data["temperature_c"] = planting.temperatureC;
  data["seed_load_raw"] = planting.seedLoadRaw;
  data["failure_code"] = planting.failureCode;
  data["firmware_version"] = FIRMWARE_VERSION;
  data["seed_count_is_estimate"] = true;
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
  JsonDocument response;
  response["status"] = "success";
  response["data"]["soil_raw"] = planting.soilRaw;
  response["data"]["soil_moisture_percent"] = planting.soilPercent;
  response["data"]["temperature_c"] = planting.temperatureC;
  response["data"]["load_raw"] = planting.seedLoadRaw;
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
  if (hasActivePlantingSession()) {
    response["status"] = "conflict";
    response["message"] = "A planting session is already active";
    return;
  }
  const String sessionId = payload["session_id"] | "";
  const String profile = payload["crop_profile"] | "";
  const int targetDrops = payload["target_drops"] | 0;
  const float spacingCm = payload["spacing_cm"] | 0;
  const unsigned long gateOpenMs = payload["gate_open_ms"] | 0;
  if (sessionId.isEmpty() || profile.isEmpty() || targetDrops <= 0 || spacingCm <= 0 || gateOpenMs < 50) {
    response["status"] = "invalid_configuration";
    response["message"] = "session_id, crop_profile, target_drops, spacing_cm, and gate_open_ms are required";
    return;
  }
  if (calibration.leftTicksPerMeter <= 0 || calibration.rightTicksPerMeter <= 0) {
    response["status"] = "calibration_required";
    response["message"] = "Calibrate both wheel encoders over one meter before planting";
    return;
  }

  planting = PlantingSession();
  planting.sessionId = sessionId;
  planting.cropProfile = profile;
  planting.fieldLabel = String(payload["field_label"] | "");
  planting.targetDrops = targetDrops;
  planting.spacingCm = spacingCm;
  planting.rowSpacingCm = payload["row_spacing_cm"] | 0;
  planting.gateOpenMs = constrain(gateOpenMs, 50UL, 3000UL);
  planting.rakeOffsetCm = payload["rake_offset_cm"] | calibration.rakeToGateCm;
  planting.nextDropAtCm = max(planting.rakeOffsetCm, 0.0f);
  planting.startedAtMs = millis();
  planting.lastHeartbeatAtMs = millis();
  resetEncoderTicks();
  safeState();
  soilSensorServo.write(soilSensorDOWN);
  setState(PlantingState::CheckingSoil);
  response["status"] = "success";
  response["data"]["accepted_command"] = "START_PLANTING_ROW";
  response["data"]["state"] = stateName(plantingState);
}

void setCalibration(JsonVariantConst payload, JsonDocument &response) {
  float value;
  if (parsePositive(payload["left_ticks_per_meter"], value)) calibration.leftTicksPerMeter = value;
  if (parsePositive(payload["right_ticks_per_meter"], value)) calibration.rightTicksPerMeter = value;
  if (!payload["soil_dry_raw"].isNull()) calibration.soilDryRaw = payload["soil_dry_raw"].as<int>();
  if (!payload["soil_wet_raw"].isNull()) calibration.soilWetRaw = payload["soil_wet_raw"].as<int>();
  if (!payload["rake_to_gate_cm"].isNull()) calibration.rakeToGateCm = max(payload["rake_to_gate_cm"].as<float>(), 0.0f);
  if (calibration.soilDryRaw == calibration.soilWetRaw) {
    response["status"] = "invalid_configuration";
    response["message"] = "Dry and wet soil calibration readings must differ";
    return;
  }
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
  } else if (command == "MOVE_FORWARD") {
    if (plantingState == PlantingState::Ready || plantingState == PlantingState::Planting) {
      planting.lastHeartbeatAtMs = millis();
      if (plantingState == PlantingState::Ready) planting.lastProgressAtMs = millis();
      moveForward();
      setState(PlantingState::Planting);
      response["status"] = "success";
    } else if (!hasActivePlantingSession()) {
      moveForward();
      response["status"] = "success";
    } else {
      response["status"] = "not_ready";
      response["message"] = "Wait until the rake is ready or resume the paused row";
      statusCode = 409;
    }
  } else if (command == "STOP") {
    if (hasActivePlantingSession()) pausePlanting(); else safeState();
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
      soilMechanismServo.write(soilMechDOWN);
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
      safeState();
      response["status"] = "movement_locked";
      response["message"] = "Reverse and turning are disabled during a planting row";
      statusCode = 409;
    } else {
      if (command == "MOVE_BACKWARD") moveBackward();
      if (command == "TURN_LEFT") turnLeft();
      if (command == "TURN_RIGHT") turnRight();
      response["status"] = "success";
    }
  } else if (command == "CHECK_SOIL") {
    soilSensorServo.write(soilSensorDOWN);
    response["status"] = "success";
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
  if (plantingState == PlantingState::CheckingSoil && now - planting.stateChangedAtMs >= SOIL_SETTLE_MS) {
    readSensorSnapshot();
    soilSensorServo.write(soilSensorUP);
    soilMechanismServo.write(soilMechDOWN);
    setState(PlantingState::LoweringRake);
    return;
  }
  if (plantingState == PlantingState::LoweringRake && now - planting.stateChangedAtMs >= RAKE_SETTLE_MS) {
    setState(PlantingState::Ready);
    return;
  }
  if (plantingState != PlantingState::Planting) return;
  if (now - planting.lastHeartbeatAtMs > FORWARD_HEARTBEAT_TIMEOUT_MS) {
    pausePlanting("HEARTBEAT_LOSS");
    return;
  }
  const float distanceCm = measuredDistanceCm();
  if (distanceCm >= planting.lastProgressCm + 0.5f) {
    planting.lastProgressCm = distanceCm;
    planting.lastProgressAtMs = now;
  } else if (!planting.gateOpen && now - planting.lastProgressAtMs > 3000) {
    finishPlanting(PlantingState::Failed, "MOTOR_STALL");
    return;
  }
  if (planting.gateOpen) {
    if (now - planting.gateOpenedAtMs >= planting.gateOpenMs) {
      closeSeedGate();
      planting.completedDrops++;
      planting.nextDropAtCm += planting.spacingCm;
      if (planting.completedDrops >= planting.targetDrops) {
        finishPlanting(PlantingState::Completed);
        readSensorSnapshot();
      }
    }
    return;
  }
  if (distanceCm >= planting.nextDropAtCm && planting.completedDrops < planting.targetDrops) {
    seedServo.write(seedOPEN);
    planting.gateOpen = true;
    planting.gateOpenedAtMs = now;
  }
}

void handleOptions() { addCommonHeaders(); server.send(204); }

void startRoverAccessPoint() {
  const IPAddress roverAddress(192, 168, 4, 1);
  const IPAddress subnet(255, 255, 255, 0);
  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);
  WiFi.softAPConfig(roverAddress, roverAddress, subnet);
  if (!WiFi.softAP("SeedRover-01", ROVER_TOKEN)) { delay(1000); ESP.restart(); return; }
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
}

void restartRoverAccessPoint(const char *reason) {
  Serial.print("SoftAP watchdog recovery: ");
  Serial.println(reason);
  if (hasActivePlantingSession()) pausePlanting("WIFI_CONNECTION_LOSS");
  WiFi.softAPdisconnect(true);
  delay(150);
  startRoverAccessPoint();
  hadConnectedClient = false;
  clientDisconnectedAt = 0;
}

void monitorRoverAccessPoint() {
  if (millis() - lastSoftApWatchdogCheck < SOFTAP_WATCHDOG_INTERVAL_MS) return;
  lastSoftApWatchdogCheck = millis();
  if (WiFi.getMode() != WIFI_AP || WiFi.softAPIP() != IPAddress(192, 168, 4, 1)) {
    restartRoverAccessPoint("AP interface became unavailable");
    return;
  }
  const int connectedClients = WiFi.softAPgetStationNum();
  if (connectedClients > 0) { hadConnectedClient = true; clientDisconnectedAt = 0; return; }
  if (!hadConnectedClient) return;
  if (clientDisconnectedAt == 0) {
    clientDisconnectedAt = millis();
    if (plantingState == PlantingState::Planting) pausePlanting("WIFI_CONNECTION_LOSS");
    return;
  }
  if (millis() - clientDisconnectedAt >= SOFTAP_RESTART_DELAY_MS) restartRoverAccessPoint("client disconnected and did not reconnect");
}

void printConnectedDeviceSignal() {
  wifi_sta_list_t stations;
  if (esp_wifi_ap_get_sta_list(&stations) != ESP_OK || stations.num == 0) return;
  Serial.printf(" | signal: %d dBm (%s)", stations.sta[0].rssi, signalQuality(stations.sta[0].rssi));
}

void setup() {
  Serial.begin(115200);
  startRoverAccessPoint();
  loadCalibration();
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
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT); pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(LEFT_ENCODER_PIN, INPUT_PULLUP); pinMode(RIGHT_ENCODER_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(LEFT_ENCODER_PIN), onLeftEncoderTick, RISING);
  attachInterrupt(digitalPinToInterrupt(RIGHT_ENCODER_PIN), onRightEncoderTick, RISING);
  temperatureSensor.begin();
  scale.begin(HX711_DT, HX711_SCK);
  soilSensorServo.setPeriodHertz(50); seedServo.setPeriodHertz(50); soilMechanismServo.setPeriodHertz(50);
  soilSensorServo.attach(SERVO_SOIL_SENSOR_PIN, 500, 2400);
  seedServo.attach(SERVO_SEED_PIN, 500, 2400);
  soilMechanismServo.attach(SERVO_SOIL_MECH_PIN, 500, 2400);
  safeState();
  Serial.printf("SeedRover %s ready at http://%s\n", FIRMWARE_VERSION, WiFi.softAPIP().toString().c_str());
}

void loop() {
  server.handleClient();
  updatePlantingStateMachine();
  monitorRoverAccessPoint();
  if (millis() - lastHealthLog >= 10000) {
    lastHealthLog = millis();
    Serial.printf("AP healthy | clients: %d | planting: %s", WiFi.softAPgetStationNum(), stateName(plantingState));
    printConnectedDeviceSignal();
    Serial.println();
  }
  delay(2);
}
