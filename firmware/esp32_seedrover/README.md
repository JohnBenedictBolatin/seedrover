# SeedRover ESP32 planting firmware

The ESP32 creates the local WPA2 hotspot `SeedRover-01` at `192.168.4.1`. DHCP leases for phones start at `192.168.4.10`, reserving `192.168.4.2` for the statically addressed ESP32-CAM and preventing an IP collision. The phone remains connected without internet while an operator plants a row; completed receipts are stored by the Flutter app and synchronized later.

## Hardware map

> **Full Engineering Schematic & Level Voltage Guide:** See [WIRING_AND_PINOUTS.md](WIRING_AND_PINOUTS.md) or [docs/wiring-schematic-and-pinouts.md](../../docs/wiring-schematic-and-pinouts.md).

- **Sensors:**
  - Soil Moisture ADC: GPIO 34 (ADC1_CH6, Wi-Fi safe)
  - DS18B20 Soil Temperature: GPIO 14 (4.7 kΩ pull-up to 3.3V)
  - DHT11 Air Temp & Humidity: GPIO 25 (10 kΩ pull-up to 3.3V)
  - Front Ultrasonic (Boundary): TRIG GPIO 5, ECHO GPIO 15 (through 1kΩ/2kΩ 3.3V divider)
  - Rear Ultrasonic (Safety/Obstacle): TRIG GPIO 16, ECHO GPIO 17 (through 1kΩ/2kΩ 3.3V divider)
- **Servos (6x on 5.5V High-Current Bus with 1000 µF cap):**
  - Seed Gate 1 (Calamansi / Default): GPIO 27
  - Seed Gate 2 (Sitaw): GPIO 4
  - Seed Gate 3 (Peanut): GPIO 23
  - Soil Rake / Furrow Opener: GPIO 26
  - Soil Flattener (after rake): GPIO 33
  - Deployable Soil Probe Arm: GPIO 13
- **DC Motors (L298N H-Bridge on 12V Raw Rail):**
  - Left Motors: IN1 GPIO 18, IN2 GPIO 19
  - Right Motors: IN3 GPIO 21, IN4 GPIO 22

The front ultrasonic uses GPIO 5 and 15, which are ESP32 boot-strapping pins. The 1kΩ/2kΩ voltage divider pulls GPIO 15 LOW on reset, ensuring normal silent boot.

Install the ESP32 board package, ArduinoJson 7, ESP32Servo, OneWire, DallasTemperature, and the Adafruit DHT sensor library. Copy `secrets.example.h` to `secrets.h`; set a unique 8-63 character token and use that exact token for the Flutter app's `ROVER_TOKEN`, this hotspot password/API header, and the camera's `ROVER_WIFI_PASSWORD`. The rover SSID is fixed to `SeedRover-01`, matching the Flutter connector and camera configuration.

Power the 8 servos from Buck 1 (5.5V 5A) with a 1000 µF 16V buffer capacitor. Power the ESP32 VIN, ESP32-CAM, and HC-SR04 VCC from Buck 2 (5.0V 2A). Power the L298N directly from the fused 12V Li-ion battery rail. Join all grounds in a central star ground, and never connect 5V directly to the 3.3V rail. Obstacle readings are warnings: the rover warns at 30 cm or less and clears above 35 cm. Missing/stale readings are reported as unavailable.

## Planting protocol

All commands are POSTed to `/command`. Planting uses:

- `PRECHECK_PLANTING_SOIL` followed by `GET /sensors`
- `CANCEL_PLANTING_PRECHECK` if the operator cancels
- `CAPTURE_SOIL_REFERENCE` followed by repeated `GET /sensors` requests during temporary moisture calibration
- `CANCEL_SOIL_REFERENCE_CAPTURE` when reference capture completes or is canceled; firmware also raises the probe after a 10-second timeout
- `START_PLANTING_ROW`
- `MOVE_FORWARD` (manual driving only, outside an automatic planting cycle)
- `STOP`
- `PAUSE_PLANTING`
- `RESUME_PLANTING`
- `CANCEL_PLANTING`
- `EMERGENCY_STOP`
- `GET_PLANTING_STATUS`
- `ACK_PLANTING_RESULT` (include the saved `session_id` after the phone has durably saved the run)
- `GET_CALIBRATION` and `SET_CALIBRATION`

`GET /planting-status` returns the run state and obstacle status independently. It also reports `rake_commanded_down`, the most recent commanded rake position; there is no physical rake-position sensor, so this is not feedback that the mechanism reached that position. Obstacle fields are `front_obstacle`, `rear_obstacle`, `front_sensor_available`, `rear_sensor_available`, and `obstacle_sample_age_ms`. Readings are latched at 30 cm and clear above 35 cm. The mobile app treats telemetry older than three seconds as unavailable. A row reports completed gate pulses as `completed_drops`; the system does not claim to know the number or remaining level of seeds.

The mobile form defaults each automatic cycle to five gate pulses. Selecting calamansi, sitaw, or peanut loads that crop's guide spacing; authorized planting managers can review the values before starting. Pulse count describes rover actions, not verified seeds planted.

Planting starts with a fresh soil pre-check (under 60 seconds). When moisture and temperature readings are available and calibrated, the app shows them for review. If a pre-check succeeds but readings are missing or unverified, the farmer may explicitly choose **Continue without soil readings**. That choice is sent with this run; unavailable values stay null and are never replaced with nominal numbers. A connection or authentication failure cannot use this override. The firmware accepts `START_PLANTING_ROW` only with a fresh rover pre-check snapshot and an explicit missing-reading override when needed.

The run sequence is: check soil and rake/measure the row; return to the start; plant along the row while flattening the soil; return to the start; then wait for the farmer's **Planted / Not planted** confirmation. Travel distance is estimated from timing. Planting points count gate cycles, not verified seeds. The pre-check snapshot and sensor-provenance version are retained with the run. Pre-upgrade checkpoints without provenance are treated as unverified. The DHT11 and obstacle sensors are sampled during operation. Obstacle warnings never pause a row. Missing app status heartbeats, losing Wi-Fi, cancelling, pressing Stop, or triggering emergency stop stops the motors, closes the gate, and raises the mechanisms. Rover run checkpoints survive power loss; unfinished runs return as `INTERRUPTED` with motors stopped and remain until the phone has saved and the farmer has confirmed the result.

Outside an automatic row, the app can independently send `SOIL_SENSOR_DOWN`, `SOIL_SENSOR_UP`, `RAKE_DOWN`, and `RAKE_UP`.

## Required calibration

Before planting, mark one meter on level ground and use a stopwatch to time how many seconds the loaded rover takes to drive that distance. The temporary mobile moisture tool captures plant-ready soil as the drier reference and wetter soil as the wetter reference. Its 0–100 output is a relative range between those samples, not laboratory volumetric water content or a plantability verdict. The tool also preserves the rover's movement-time and rake-to-gate calibration. Gate-open duration is configured per row; no seed-count estimate is used.

Distance and spacing are estimates because the rover has no wheel movement sensor. Ultrasonic sensors detect nearby front/rear obstacles; they do not measure travel distance or detect wheel slip. Recalibrate the one-meter time whenever the power system, payload, wheels, soil surface, or rake drag changes. The firmware cannot detect a stalled motor, so planting must remain operator-supervised.
