#include "esp_camera.h"
#include <WebServer.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// Automatically include camera secrets, rover secrets, or use fallback defaults
#if __has_include("camera_secrets.h")
#include "camera_secrets.h"
#elif __has_include("../esp32_seedrover/secrets.h")
#include "../esp32_seedrover/secrets.h"
#endif

// Fallback credentials matching the main SeedRover system configuration
#ifndef ROVER_WIFI_SSID
#define ROVER_WIFI_SSID "SeedRover-01"
#endif

#ifndef ROVER_WIFI_PASSWORD
#ifdef ROVER_TOKEN
#define ROVER_WIFI_PASSWORD ROVER_TOKEN
#else
#define ROVER_WIFI_PASSWORD "HLjHgNQoRsD1gqsBgF2zptRZXOXrVr-VqCfqZqQOjSA"
#endif
#endif

#ifndef FALLBACK_WIFI_SSID
#ifdef WIFI_SSID
#define FALLBACK_WIFI_SSID WIFI_SSID
#else
#define FALLBACK_WIFI_SSID "MAXWELL"
#endif
#endif

#ifndef FALLBACK_WIFI_PASSWORD
#ifdef WIFI_PASSWORD
#define FALLBACK_WIFI_PASSWORD WIFI_PASSWORD
#else
#define FALLBACK_WIFI_PASSWORD "maxwell11"
#endif
#endif

// AI-Thinker ESP32-CAM Pin Mapping
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Onboard Red Diagnostic LED (Active LOW: LOW = ON, HIGH = OFF)
#define STATUS_LED_PIN    33

// Static IP configuration aligned with SeedRover subnet (192.168.4.0/24)
// Rover is 192.168.4.1; Camera is 192.168.4.2; Phone clients start at 192.168.4.10+
const IPAddress CAMERA_STATIC_IP(192, 168, 4, 2);
const IPAddress ROVER_GATEWAY_IP(192, 168, 4, 1);
const IPAddress SUBNET_MASK(255, 255, 255, 0);

WebServer server(80);

bool cameraInitialized = false;
unsigned long lastWifiAttemptMs = 0;
unsigned long lastStatusLogMs = 0;
unsigned long lastLedBlinkMs = 0;
bool ledState = false;
bool usingFallbackNetwork = false;
int reconnectFailCount = 0;

void setStatusLed(bool on) {
  // Built-in LED on GPIO 33 is active-low
  digitalWrite(STATUS_LED_PIN, on ? LOW : HIGH);
}

void toggleStatusLed() {
  ledState = !ledState;
  digitalWrite(STATUS_LED_PIN, ledState ? LOW : HIGH);
}

void sendCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type,X-Rover-Token,Cache-Control");
  server.sendHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  server.sendHeader("Pragma", "no-cache");
}

void handleOptions() {
  sendCorsHeaders();
  server.send(204);
}

void handleRoot() {
  sendCorsHeaders();
  String html = R"HTML(<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>SeedRover Camera Preview</title>
  <style>
    body { margin:0; background:#0d1117; color:#c9d1d9; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; text-align:center; padding:16px; }
    h1 { color:#2ea043; font-size:22px; margin-bottom:8px; }
    .status { font-size:14px; color:#8b949e; margin-bottom:16px; }
    .badge { display:inline-block; padding:3px 10px; border-radius:12px; font-weight:600; font-size:12px; }
    .badge-ok { background:#238636; color:#fff; }
    .card { max-width:640px; margin:0 auto; background:#161b22; border:1px solid #30363d; border-radius:12px; padding:16px; box-shadow:0 8px 24px rgba(0,0,0,0.5); }
    img { width:100%; height:auto; border-radius:8px; border:1px solid #30363d; display:block; background:#000; }
    .info { margin-top:12px; font-size:12px; color:#8b949e; line-height:1.6; }
  </style>
</head>
<body>
  <div class="card">
    <h1>SeedRover-01 Live Camera</h1>
    <div class="status">
      Status: <span class="badge badge-ok">Online</span> &nbsp;|&nbsp;
      IP: <strong>)HTML";
  html += WiFi.localIP().toString();
  html += R"HTML(</strong> &nbsp;|&nbsp;
      Network: <strong>)HTML";
  html += WiFi.SSID();
  html += R"HTML(</strong>
    </div>
    <img src="/stream" alt="Live Stream">
    <div class="info">
      Endpoints: <code>/stream</code> (MJPEG Stream) &bull; <code>/capture</code> (JPEG Frame) &bull; <code>/health</code> (Status JSON)
    </div>
  </div>
</body>
</html>)HTML";
  server.send(200, "text/html", html);
}

void handleCapture() {
  camera_fb_t* frame = esp_camera_fb_get();
  if (frame == nullptr) {
    server.send(503, "text/plain", "Camera capture failed");
    return;
  }
  sendCorsHeaders();
  server.setContentLength(frame->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(frame->buf, frame->len);
  esp_camera_fb_return(frame);
}

void handleStream() {
  if (!cameraInitialized) {
    sendCorsHeaders();
    server.send(503, "text/plain", "Camera sensor hardware not initialized. Check OV2640 ribbon connector.");
    return;
  }
  WiFiClient client = server.client();
  client.print(
      "HTTP/1.1 200 OK\r\n"
      "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "Access-Control-Allow-Methods: GET,POST,OPTIONS\r\n"
      "Access-Control-Allow-Headers: Content-Type,X-Rover-Token\r\n"
      "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
      "Pragma: no-cache\r\n\r\n");

  while (client.connected()) {
    camera_fb_t* frame = esp_camera_fb_get();
    if (frame == nullptr) break;

    client.printf("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", frame->len);
    size_t written = client.write(frame->buf, frame->len);
    client.print("\r\n");
    esp_camera_fb_return(frame);

    // If client disconnected or socket write failed (e.g. user navigated away), exit immediately!
    if (written != frame->len || !client.connected()) {
      break;
    }

    // Yield to allow network stack and WebServer tasks to breathe (~16-18 FPS)
    delay(55);
  }
  client.stop();
}

void handleStatus() {
  sendCorsHeaders();
  String body = "{\"status\":\"online\",\"device\":\"esp32-cam\",\"model\":\"AI-Thinker ESP32-CAM\",\"ip\":\"";
  body += WiFi.localIP().toString();
  body += "\",\"ssid\":\"";
  body += WiFi.SSID();
  body += "\",\"rssi\":";
  body += String(WiFi.RSSI());
  body += ",\"stream\":\"http://";
  body += WiFi.localIP().toString();
  body += "/stream\"}";
  server.send(200, "application/json", body);
}

void handleHealth() {
  sendCorsHeaders();
  String body = "{\"status\":\"success\",\"device\":\"SeedRover-CAM\",\"camera\":\"AI-Thinker OV2640\",\"ip\":\"";
  body += WiFi.localIP().toString();
  body += "\",\"connected\":";
  body += (WiFi.status() == WL_CONNECTED ? "true" : "false");
  body += ",\"camera_ready\":";
  body += (cameraInitialized ? "true" : "false");
  body += ",\"psram\":";
  body += (psramFound() ? "true" : "false");
  body += ",\"ssid\":\"";
  body += WiFi.SSID();
  body += "\",\"rssi\":";
  body += String(WiFi.RSSI());
  body += ",\"uptime_ms\":";
  body += String(millis());
  body += ",\"free_heap\":";
  body += String(ESP.getFreeHeap());
  body += ",\"stream\":\"http://";
  body += WiFi.localIP().toString();
  body += "/stream\"}";
  server.send(200, "application/json", body);
}

void setupCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // Utilize PSRAM if available for higher resolution & double buffering (zero lag)
  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;      // 640x480 resolution
    config.jpeg_quality = 12;               // 10-12 gives crisp frames at good fps
    config.fb_count = 2;                    // Double buffering prevents tearing
    config.grab_mode = CAMERA_GRAB_LATEST;  // Always latest frame for real-time rover driving
  } else {
    config.frame_size = FRAMESIZE_QVGA;     // 320x240 resolution fallback
    config.jpeg_quality = 15;
    config.fb_count = 1;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  }

  const esp_err_t result = esp_camera_init(&config);
  if (result != ESP_OK) {
    cameraInitialized = false;
    Serial.printf("[CAMERA] Camera init failed with error: 0x%x (Check ribbon cable / PSRAM settings)\n", result);
    // Continue running so Wi-Fi and diagnostics remain accessible
  } else {
    cameraInitialized = true;
    Serial.println("[CAMERA] OV2640 camera initialized successfully.");
  }
}

void startStationConnection(bool useFallback = false) {
  WiFi.disconnect(false, false);
  delay(100);

  if (!useFallback) {
    usingFallbackNetwork = false;
    // Static IP aligned with rover network: 192.168.4.2
    WiFi.config(CAMERA_STATIC_IP, ROVER_GATEWAY_IP, SUBNET_MASK, ROVER_GATEWAY_IP);
    Serial.printf("[CAM WIFI] Connecting to primary rover hotspot: '%s' (Channel 1)...\n", ROVER_WIFI_SSID);
    // Direct connection to Channel 1 (where SeedRover-01 AP operates) avoids full 13-channel scans
    WiFi.begin(ROVER_WIFI_SSID, ROVER_WIFI_PASSWORD, 1);
  } else {
    usingFallbackNetwork = true;
    // Clear static IP for standard DHCP when connecting to external router
    WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE, INADDR_NONE);
    Serial.printf("[CAM WIFI] Connecting to fallback router network: '%s'...\n", FALLBACK_WIFI_SSID);
    WiFi.begin(FALLBACK_WIFI_SSID, FALLBACK_WIFI_PASSWORD);
  }
}

void initWifi() {
  WiFi.mode(WIFI_STA);

  // Set country policy (PH 1-13) matching rover firmware
  const wifi_country_t philippines = {"PH", 1, 13, WIFI_COUNTRY_POLICY_MANUAL};
  esp_wifi_set_country(&philippines);

  // CRITICAL: Disable modem sleep to prevent high latency, frame drops, and stream stutter
  WiFi.setSleep(false);

  // Set Wi-Fi TX power to 17dBm to match rover and avoid peak current brownout resets
  WiFi.setTxPower(WIFI_POWER_17dBm);

  WiFi.setAutoReconnect(true);
  WiFi.setHostname("SeedRover-CAM");

  startStationConnection(false);

  // Quick initial probe (up to 3 seconds) so if rover is already on, it associates immediately
  Serial.print("[CAM WIFI] Associating");
  for (int attempt = 0; attempt < 12 && WiFi.status() != WL_CONNECTED; attempt++) {
    delay(250);
    Serial.print('.');
    toggleStatusLed();
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    setStatusLed(true);
    Serial.printf("[CAM WIFI] Connected! IP address: %s | Signal: %d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    setStatusLed(false);
    Serial.println("[CAM WIFI] Rover AP not immediately ready. Background monitor will maintain connection.");
  }
}

void monitorCameraWifi() {
  const unsigned long now = millis();

  // If connected, keep status LED on
  if (WiFi.status() == WL_CONNECTED) {
    setStatusLed(true);
    reconnectFailCount = 0;
  } else {
    // Blink LED every 500ms when attempting to connect/reconnect
    if (now - lastLedBlinkMs >= 500) {
      lastLedBlinkMs = now;
      toggleStatusLed();
    }

    // Attempt reconnection non-blockingly every 5 seconds
    if (now - lastWifiAttemptMs > 5000) {
      lastWifiAttemptMs = now;
      reconnectFailCount++;

      // If rover hotspot was not reached after 5 attempts and a fallback SSID is defined, test fallback
      if (reconnectFailCount > 5 && strlen(FALLBACK_WIFI_SSID) > 0 && !usingFallbackNetwork) {
        Serial.println("[CAM WIFI] Rover hotspot unreached after retries. Attempting fallback router...");
        startStationConnection(true);
      } else if (usingFallbackNetwork && reconnectFailCount > 8) {
        // Try rover hotspot again
        Serial.println("[CAM WIFI] Returning to scan for SeedRover-01 hotspot...");
        startStationConnection(false);
      } else {
        Serial.printf("[CAM WIFI] Retrying connection to '%s'...\n",
                      usingFallbackNetwork ? FALLBACK_WIFI_SSID : ROVER_WIFI_SSID);
        WiFi.reconnect();
      }
    }
  }

  // Periodic status banner every 10 seconds (aligned with rover loop)
  if (now - lastStatusLogMs >= 10000) {
    lastStatusLogMs = now;
    if (WiFi.status() == WL_CONNECTED) {
      Serial.printf("[CAM STATUS] Online | SSID: %s | IP: %s | RSSI: %d dBm | Free Heap: %u\n",
                    WiFi.SSID().c_str(), WiFi.localIP().toString().c_str(), WiFi.RSSI(), ESP.getFreeHeap());
    } else {
      Serial.printf("[CAM STATUS] Searching for %s... | Retries: %d | Free Heap: %u\n",
                    usingFallbackNetwork ? FALLBACK_WIFI_SSID : ROVER_WIFI_SSID,
                    reconnectFailCount, ESP.getFreeHeap());
    }
  }
}

void setup() {
  // Disable brownout detector to prevent reboot loops during high RF transmit bursts
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  delay(100);

  pinMode(STATUS_LED_PIN, OUTPUT);
  setStatusLed(false);

  Serial.println("\n==========================================");
  Serial.println("     SeedRover ESP32-CAM Firmware Boot    ");
  Serial.println("==========================================");

  Serial.println("[BOOT] 1. Initializing Camera Hardware...");
  setupCamera();

  Serial.println("[BOOT] 2. Configuring Wi-Fi Station & Network...");
  initWifi();

  Serial.println("[BOOT] 3. Starting Camera Web Server...");
  server.on("/", HTTP_GET, handleRoot);
  server.on("/", HTTP_OPTIONS, handleOptions);
  server.on("/capture", HTTP_GET, handleCapture);
  server.on("/capture", HTTP_OPTIONS, handleOptions);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/stream", HTTP_OPTIONS, handleOptions);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/status", HTTP_OPTIONS, handleOptions);
  server.on("/health", HTTP_GET, handleHealth);
  server.on("/health", HTTP_OPTIONS, handleOptions);
  server.begin();

  Serial.println("[BOOT] 4. Camera Web Server Online.");
  Serial.println("------------------------------------------");
  Serial.printf("  Camera IP:   http://%s\n", WiFi.localIP().toString().c_str());
  Serial.printf("  Live Stream: http://%s/stream\n", WiFi.localIP().toString().c_str());
  Serial.printf("  Snapshot:    http://%s/capture\n", WiFi.localIP().toString().c_str());
  Serial.printf("  Health Check:http://%s/health\n", WiFi.localIP().toString().c_str());
  Serial.println("==========================================\n");
}

void loop() {
  server.handleClient();
  monitorCameraWifi();
  delay(2);
}
