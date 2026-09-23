#include "esp_camera.h"
#include <WebServer.h>
#include <WiFi.h>
#include <esp_wifi.h>

#include "camera_secrets.h"

// AI-Thinker ESP32-CAM pin map.
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

WebServer server(80);

void sendCors() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Cache-Control", "no-store");
}

void handleRoot() {
  sendCors();
  server.send(200, "text/html", R"HTML(
<!doctype html><html><head><title>SeedRover Camera</title></head>
<body style="margin:0;background:#111;color:#fff;font-family:Arial;text-align:center">
<h2>SeedRover Camera</h2><img src="/stream" style="max-width:100%;height:auto">
</body></html>)HTML");
}

void handleCapture() {
  camera_fb_t* frame = esp_camera_fb_get();
  if (frame == nullptr) {
    server.send(503, "text/plain", "Camera capture failed");
    return;
  }
  sendCors();
  server.setContentLength(frame->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(frame->buf, frame->len);
  esp_camera_fb_return(frame);
}

void handleStream() {
  WiFiClient client = server.client();
  client.print(
      "HTTP/1.1 200 OK\r\n"
      "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "Cache-Control: no-store\r\n\r\n");

  while (client.connected()) {
    camera_fb_t* frame = esp_camera_fb_get();
    if (frame == nullptr) break;
    client.printf("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", frame->len);
    client.write(frame->buf, frame->len);
    client.print("\r\n");
    esp_camera_fb_return(frame);
    delay(80);
  }
  client.stop();
}

void handleStatus() {
  sendCors();
  String body = "{\"status\":\"online\",\"camera\":\"AI-Thinker ESP32-CAM\",\"ip\":\"";
  body += WiFi.localIP().toString();
  body += "\",\"stream\":\"http://";
  body += WiFi.localIP().toString();
  body += "/stream\"}";
  server.send(200, "application/json", body);
}

bool connectToRover() {
  WiFi.mode(WIFI_STA);
  const wifi_country_t philippines = {"PH", 1, 13, WIFI_COUNTRY_POLICY_MANUAL};
  esp_wifi_set_country(&philippines);
  WiFi.disconnect(false, false);
  delay(500);
  WiFi.setAutoReconnect(true);
  WiFi.config(
      IPAddress(192, 168, 4, 2),
      IPAddress(192, 168, 4, 1),
      IPAddress(255, 255, 255, 0),
      IPAddress(192, 168, 4, 1));
  Serial.println("Scanning for Wi-Fi networks...");
  const int networkCount = WiFi.scanNetworks();
  for (int index = 0; index < networkCount; index++) {
    Serial.print("Found: ");
    Serial.print(WiFi.SSID(index));
    Serial.print(" | RSSI: ");
    Serial.print(WiFi.RSSI(index));
    Serial.print(" | channel: ");
    Serial.println(WiFi.channel(index));
  }
  WiFi.begin(ROVER_WIFI_SSID, ROVER_WIFI_PASSWORD);
  Serial.print("Connecting to ");
  Serial.println(ROVER_WIFI_SSID);
  for (int attempt = 0; attempt < 30 && WiFi.status() != WL_CONNECTED; attempt++) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();
  Serial.print("Wi-Fi status code: ");
  Serial.println(WiFi.status());
  return WiFi.status() == WL_CONNECTED;
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
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 15;
  config.fb_count = 1;
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;

  const esp_err_t result = esp_camera_init(&config);
  if (result != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", result);
    while (true) delay(1000);
  }
}

void setup() {
  Serial.begin(115200);
  setupCamera();
  if (!connectToRover()) {
    Serial.println("Could not join SeedRover-01. Check the camera password.");
    while (true) delay(1000);
  }

  server.on("/", HTTP_GET, handleRoot);
  server.on("/capture", HTTP_GET, handleCapture);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/status", HTTP_GET, handleStatus);
  server.begin();
  Serial.print("Camera ready at http://");
  Serial.println(WiFi.localIP());
  Serial.print("Stream: http://");
  Serial.print(WiFi.localIP());
  Serial.println("/stream");
}

void loop() {
  server.handleClient();
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    delay(1000);
  }
}
