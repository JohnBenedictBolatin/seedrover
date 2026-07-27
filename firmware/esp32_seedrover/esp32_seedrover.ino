#include <ArduinoJson.h>
#include <WebServer.h>
#include <WiFi.h>
#include <esp_wifi.h>

#include "secrets.h"

WebServer server(80);
unsigned long lastHealthLog = 0;
unsigned long clientDisconnectedAt = 0;
unsigned long lastSoftApWatchdogCheck = 0;
bool hadConnectedClient = false;

const unsigned long SOFTAP_RESTART_DELAY_MS = 5000;
const unsigned long SOFTAP_WATCHDOG_INTERVAL_MS = 2000;

const char* signalQuality(int rssi) {
  if (rssi >= -50) return "excellent";
  if (rssi >= -60) return "good";
  if (rssi >= -70) return "fair";
  return "weak";
}

void printConnectedDeviceSignal() {
  wifi_sta_list_t stations;
  if (esp_wifi_ap_get_sta_list(&stations) != ESP_OK || stations.num == 0) {
    Serial.print(" | client signal: not connected");
    return;
  }

  const int rssi = stations.sta[0].rssi;
  const uint8_t* mac = stations.sta[0].mac;
  Serial.printf(
    " | client MAC: %02X:%02X:%02X:%02X:%02X:%02X",
    mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]
  );
  Serial.print(" | client signal: ");
  Serial.print(rssi);
  Serial.print(" dBm (");
  Serial.print(signalQuality(rssi));
  Serial.print(")");
}

void addCommonHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type, X-Rover-Token");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
}

void sendJson(int statusCode, JsonDocument& document) {
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
  Serial.println("Request rejected: incorrect X-Rover-Token");
  return false;
}

void handleHealth() {
  Serial.println("GET /health");
  if (!authorizeRequest()) return;
  JsonDocument response;
  response["status"] = "success";
  response["data"]["rover"] = "SeedRover-01";
  response["data"]["transport"] = "local_wifi";
  response["data"]["uptime_ms"] = millis();
  sendJson(200, response);
}

void handleCommand() {
  Serial.println("POST /command");
  if (!authorizeRequest()) return;

  const String body = server.arg("plain");
  Serial.print("Request body: ");
  Serial.println(body);

  JsonDocument request;
  const DeserializationError error = deserializeJson(request, body);
  if (error) {
    JsonDocument response;
    response["status"] = "failed";
    response["message"] = "Invalid JSON";
    sendJson(400, response);
    return;
  }

  const char* commandId = request["command_id"] | "";
  const char* command = request["command"] | "";
  JsonDocument response;
  response["command_id"] = commandId;
  response["timestamp"] = millis();

  if (strcmp(command, "PING") == 0) {
    response["status"] = "success";
    response["data"]["reply"] = "PONG";
    Serial.println("PING accepted -> PONG");
    sendJson(200, response);
    return;
  }

  const char* simulatedCommands[] = {
    "MOVE_FORWARD",
    "MOVE_BACKWARD",
    "TURN_LEFT",
    "TURN_RIGHT",
    "STOP",
    "CHECK_SOIL",
    "START_PLANTING",
    "PAUSE_PLANTING",
    "RESUME_PLANTING",
    "STOP_PLANTING",
    "EMERGENCY_STOP",
  };
  for (const char* acceptedCommand : simulatedCommands) {
    if (strcmp(command, acceptedCommand) == 0) {
      response["status"] = "success";
      response["data"]["accepted_command"] = command;
      response["data"]["simulation"] = true;
      Serial.print("COMMAND accepted (simulation only): ");
      Serial.println(command);
      sendJson(200, response);
      return;
    }
  }

  response["status"] = "invalid_command";
  response["message"] = "Unsupported simulation command";
  sendJson(400, response);
}

void handleOptions() {
  addCommonHeaders();
  server.send(204);
}

void startRoverAccessPoint() {
  const IPAddress roverAddress(192, 168, 4, 1);
  const IPAddress gateway(192, 168, 4, 1);
  const IPAddress subnet(255, 255, 255, 0);

  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);
  WiFi.softAPConfig(roverAddress, gateway, subnet);

  const bool started = WiFi.softAP("SeedRover-01", ROVER_TOKEN);
  if (!started) {
    Serial.println("SoftAP failed to start. ROVER_TOKEN must be 8-63 characters.");
    Serial.println("Restarting ESP32 to recover the Wi-Fi access point...");
    delay(1000);
    ESP.restart();
    return;
  }
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  Serial.println("SeedRover Wi-Fi started");
  Serial.println("Network name: SeedRover-01");
  Serial.println("Wi-Fi password: use the same value as ROVER_TOKEN");
  Serial.print("ESP32 address: http://");
  Serial.println(WiFi.softAPIP());
}

void restartRoverAccessPoint(const char* reason) {
  Serial.print("SoftAP watchdog recovery: ");
  Serial.println(reason);
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
  if (connectedClients > 0) {
    hadConnectedClient = true;
    clientDisconnectedAt = 0;
    return;
  }

  if (!hadConnectedClient) return;
  if (clientDisconnectedAt == 0) {
    clientDisconnectedAt = millis();
    Serial.println("SoftAP client disconnected; scheduling Wi-Fi recovery");
    return;
  }

  if (millis() - clientDisconnectedAt >= SOFTAP_RESTART_DELAY_MS) {
    restartRoverAccessPoint("client disconnected and did not reconnect");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println();
  Serial.println("==============================");
  Serial.println("Starting SeedRover SoftAP Phase 1");
  Serial.println("==============================");

  startRoverAccessPoint();

  const char* headers[] = {"X-Rover-Token"};
  server.collectHeaders(headers, 1);
  server.on("/health", HTTP_GET, handleHealth);
  server.on("/health", HTTP_OPTIONS, handleOptions);
  server.on("/command", HTTP_POST, handleCommand);
  server.on("/command", HTTP_OPTIONS, handleOptions);
  server.onNotFound([]() {
    JsonDocument response;
    response["status"] = "failed";
    response["message"] = "Not found";
    sendJson(404, response);
  });
  server.begin();
  Serial.println("SeedRover local command server started");
}

void loop() {
  server.handleClient();
  monitorRoverAccessPoint();

  if (millis() - lastHealthLog >= 10000) {
    lastHealthLog = millis();
    Serial.print("SoftAP healthy: yes | IP: ");
    Serial.print(WiFi.softAPIP());
    Serial.print(" | connected devices: ");
    Serial.print(WiFi.softAPgetStationNum());
    printConnectedDeviceSignal();
    Serial.println();
  }

  delay(2);
}
