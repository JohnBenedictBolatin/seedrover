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

GPIO 32 and 33 are not used. This version does not require wheel encoders or another movement sensor.

Install the ESP32 board package, ArduinoJson, ESP32Servo, OneWire, DallasTemperature, and HX711. Copy `secrets.example.h` to `secrets.h`; use the same 8-63 character token for the hotspot and `X-Rover-Token` API header.

## Planting protocol

All commands are POSTed to `/command`. Planting uses:

- `START_PLANTING_ROW`
- `MOVE_FORWARD` (manual driving only, outside an automatic planting cycle)
- `STOP`
- `PAUSE_PLANTING`
- `RESUME_PLANTING`
- `CANCEL_PLANTING`
- `EMERGENCY_STOP`
- `GET_PLANTING_STATUS`
- `GET_CALIBRATION` and `SET_CALIBRATION`

`GET /planting-status` returns the same live status data. A row reports completed gate pulses as `completed_drops`; actual seed totals are always estimates based on gate calibration.

The mobile form defaults each automatic cycle to five gate pulses. Selecting calamansi, sitaw, or peanut loads that crop's guide spacing; authorized planting managers can review the values before starting.

The non-blocking state machine lowers and reads the soil probe, raises the probe, lowers the rake, starts forward movement, accounts for the rake-to-gate offset, stops briefly for each time-estimated crop-spacing gate pulse, resumes forward movement, and stops at the target drop count. All directional commands except Stop are locked while an automatic row is active. Missing app status heartbeats, losing Wi-Fi, cancelling, pressing Stop, or triggering emergency stop stops the motors, closes the gate, and raises the mechanisms.

Outside an automatic row, the app can independently send `SOIL_SENSOR_DOWN`, `SOIL_SENSOR_UP`, `RAKE_DOWN`, and `RAKE_UP`.

## Required calibration

Before planting, mark one meter on level ground and use a stopwatch to time how many seconds the loaded rover takes to drive that distance. Enter that time, the dry and wet soil readings, and the rake-to-gate distance in the app. Gate-open duration and estimated seeds per pulse are configured per row.

Distance and spacing are estimates because the rover has no movement sensor. Recalibrate the one-meter time whenever the battery, payload, wheels, soil surface, or rake drag changes. The firmware cannot detect wheel slip or a stalled motor, so planting must remain operator-supervised.
