#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

// This sketch tests only the ESP32 Bluetooth radio and advertisement.
// It contains no SeedRover protocol, token, Wi-Fi, or motor code.

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("Starting basic ESP32 BLE diagnostic...");

  BLEDevice::init("ESP32-BLE-TEST");
  BLEDevice::setPower(ESP_PWR_LVL_P9);

  Serial.print("ESP32 Bluetooth address: ");
  Serial.println(BLEDevice::getAddress().toString().c_str());

  BLEServer* server = BLEDevice::createServer();
  BLEService* service = server->createService("FFE0");
  BLECharacteristic* characteristic = service->createCharacteristic(
    "FFE1",
    BLECharacteristic::PROPERTY_READ
  );

  const char* diagnosticStatus = "OK";
  characteristic->setValue(diagnosticStatus);
  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID("FFE0");
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMaxPreferred(0x12);
  advertising->start();

  Serial.println("Advertising as: ESP32-BLE-TEST");
  Serial.println("Open nRF Connect and scan for that exact name.");
}

void loop() {
  static unsigned long lastMessage = 0;
  if (millis() - lastMessage >= 5000) {
    lastMessage = millis();
    Serial.println("Diagnostic is still running and advertising...");
  }
  delay(20);
}
