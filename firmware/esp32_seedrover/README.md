# SeedRover ESP32 planting firmware

The ESP32 creates the local WPA2 hotspot `SeedRover-01` at `192.168.4.1`. The phone remains connected without internet while an operator plants a row; completed receipts are stored by the Flutter app and synchronized later.

## Hardware map

- Soil ADC: GPIO 34
- DS18B20 temperature: GPIO 14
- HX711: DT GPIO 23, SCK GPIO 4
- Soil probe servo: GPIO 13
- Seed gate servo: GPIO 27
- Rake servo: GPIO 26
- Motor driver: GPIO 18, 19, 21, and 22
- Left and right single-channel encoders: GPIO 32 and 33

Install the ESP32 board package, ArduinoJson, ESP32Servo, OneWire, DallasTemperature, and HX711. Copy `secrets.example.h` to `secrets.h`; use the same 8-63 character token for the hotspot and `X-Rover-Token` API header.

## Planting protocol

All commands are POSTed to `/command`. Planting uses:

- `START_PLANTING_ROW`
- `MOVE_FORWARD` (repeat while the operator holds Forward)
- `STOP`
- `PAUSE_PLANTING`
- `RESUME_PLANTING`
- `CANCEL_PLANTING`
- `EMERGENCY_STOP`
- `GET_PLANTING_STATUS`
- `GET_CALIBRATION` and `SET_CALIBRATION`

`GET /planting-status` returns the same live status data. A row reports completed gate pulses as `completed_drops`; actual seed totals are always estimates based on gate calibration.

The non-blocking state machine checks soil, lowers the rake, waits for Forward, accounts for the rake-to-gate offset, pulses at encoder-measured intervals, and stops at the target drop count. Reverse and turning are locked while a row is active. Releasing Forward sends Stop; missing repeated Forward heartbeats, losing Wi-Fi, cancelling, or triggering emergency stop stops the motors, closes the gate, and raises the mechanisms.

## Required calibration

Before planting, record left and right encoder ticks from a measured one-meter roll, dry and wet soil readings, and rake-to-gate distance. Gate-open duration and estimated seeds per pulse are configured per row in the app. Recalibrate after changing wheel diameter, encoder mounting, seed type, gate hardware, or soil probe.
