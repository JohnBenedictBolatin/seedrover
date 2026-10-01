# SeedRover ESP32 planting firmware

The ESP32 creates the local WPA2 hotspot `SeedRover-01` at `192.168.4.1`. DHCP leases for phones start at `192.168.4.10`, reserving `192.168.4.2` for the statically addressed ESP32-CAM and preventing an IP collision. The phone remains connected without internet while an operator plants a row; completed receipts are stored by the Flutter app and synchronized later.

## Hardware map

- Soil ADC: GPIO 34
- DS18B20 temperature: GPIO 14
- DHT11 data: GPIO 25
- Front HC-SR04: TRIG GPIO 5, ECHO GPIO 15 through voltage divider
- Rear HC-SR04: TRIG GPIO 16, ECHO GPIO 17 through voltage divider
- Soil probe servo: GPIO 13
- Seed gate servo: GPIO 27
- Rake servo: GPIO 26
- Motor driver: GPIO 18, 19, 21, and 22

GPIO 4 and 23 are unused. The HX711 and load cell are removed. This version does not have wheel encoders, so travel distance remains a timed estimate.

The front ultrasonic now uses GPIO 5 and 15, which are ESP32 boot-strapping pins. Keep the modules from driving those pins during reset and cold-boot the board with the sensors connected; if boot becomes unreliable, move that sensor to non-strapping GPIOs and update these definitions and this table together.

Install the ESP32 board package, ArduinoJson 7, ESP32Servo, OneWire, DallasTemperature, and the Adafruit DHT sensor library. Copy `secrets.example.h` to `secrets.h`; set a unique 8-63 character token and use that exact token for the Flutter app's `ROVER_TOKEN`, this hotspot password/API header, and the camera's `ROVER_WIFI_PASSWORD`. The rover SSID is fixed to `SeedRover-01`, matching the Flutter connector and camera configuration.

The DS18B20 measures soil temperature. The DHT11 measures air temperature and humidity. For a bare DS18B20, use a 4.7 kOhm DATA pull-up to 3.3V; a bare 4-pin DHT11 needs a 4.7-10 kOhm DATA pull-up (a module may already include it). A disconnected or invalid sensor is reported as unavailable, never as a measured zero.

Power both HC-SR04 modules from 5V and share common ground. Protect each 5V ECHO output with a divider: ECHO → one 1 kOhm resistor → GPIO junction → two 1 kOhm resistors in series → ground. This produces about 3.3V at the GPIO; never connect ECHO directly to an ESP32 pin. Power the three servos from Buck 2 and use the separate motor power circuit. Join all grounds, and never connect 5V directly to the 3.3V rail. Obstacle readings are warnings only: they never reject start/resume or stop automatic/manual movement. The rover warns at 30 cm or less and clears a warning only above 35 cm. Missing/stale readings are reported as unavailable; they do not claim the path is clear.

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

Planting requires a fresh (under 60 seconds), calibrated moisture and valid soil-temperature pre-check. The firmware accepts `START_PLANTING_ROW` only when its `soil_sampled_at_ms` matches that exact pre-check snapshot; the mobile app presents the values for operator review and does not invent crop suitability thresholds. On acceptance, the state machine lowers the rake and starts forward movement, accounts for the rake-to-gate offset, stops briefly for each time-estimated crop-spacing gate pulse, resumes forward movement, and stops at the target drop count. The pre-check snapshot is retained with the planting run. The DHT11 and obstacle sensors are sampled during operation. Obstacle warnings never pause a row. Missing app status heartbeats, losing Wi-Fi, cancelling, pressing Stop, or triggering emergency stop stops the motors, closes the gate, and raises the mechanisms. Rover run checkpoints survive power loss; unfinished runs return as `INTERRUPTED` with motors stopped and are retained until the phone acknowledges saving the result.

Outside an automatic row, the app can independently send `SOIL_SENSOR_DOWN`, `SOIL_SENSOR_UP`, `RAKE_DOWN`, and `RAKE_UP`.

## Required calibration

Before planting, mark one meter on level ground and use a stopwatch to time how many seconds the loaded rover takes to drive that distance. The temporary mobile moisture tool captures plant-ready soil as the drier reference and wetter soil as the wetter reference. Its 0–100 output is a relative range between those samples, not laboratory volumetric water content or a plantability verdict. The tool also preserves the rover's movement-time and rake-to-gate calibration. Gate-open duration is configured per row; no seed-count estimate is used.

Distance and spacing are estimates because the rover has no wheel movement sensor. Ultrasonic sensors detect nearby front/rear obstacles; they do not measure travel distance or detect wheel slip. Recalibrate the one-meter time whenever the power system, payload, wheels, soil surface, or rake drag changes. The firmware cannot detect a stalled motor, so planting must remain operator-supervised.
