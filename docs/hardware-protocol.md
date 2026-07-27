# SeedRover Hardware Communication Protocol

Version: 1.0

## Phase 1 Local Wi-Fi SoftAP Transport

The ESP32 creates the WPA2 network `SeedRover-01` at `192.168.4.1`. The
Android phone connects directly to this network and sends authenticated HTTP
requests to `/health` and `/command`. The `ROVER_TOKEN` value is used as both
the SoftAP password and the `X-Rover-Token` request header during this
prototype phase, and must be 8–63 characters.

The app sends `PING` to `POST /command` and expects a matching `command_id`, a
`success` status, and `data.reply: "PONG"`. No router or internet connection is
required for local PING.

During hardware-integration simulation, movement, soil-check, planting, and
emergency-stop commands return `data.accepted_command` and
`data.simulation: true`. The firmware logs these commands but does not energize
motors, relays, or actuators.

## Phase 1 Bluetooth Low Energy Transport

The ESP32 advertises as `SeedRover-01`. Android connects over BLE while normal
Wi-Fi or mobile data remains available. Phase 1 uses service UUID
`7b100001-0d91-4b68-a5e2-1b7ecb100001`, command UUID
`7b100002-0d91-4b68-a5e2-1b7ecb100002`, and response UUID
`7b100003-0d91-4b68-a5e2-1b7ecb100003`.

The app writes this JSON to the command characteristic:

```json
{
  "command_id": "PING-unique-id",
  "command": "PING",
  "token": "shared-local-token",
  "payload": {}
}
```

The ESP32 notifies the response characteristic with the matching `command_id`,
`status: "success"`, and `data.reply: "PONG"`. The app rejects mismatched or
malformed responses and times out after five seconds.

Only `PING` is executable in Phase 1. Unknown commands return
`invalid_command`, invalid JSON returns `failed`, and a missing or incorrect
token returns `failed` with `Unauthorized`. There is deliberately no actuator
code in the Phase 1 firmware.

## Deployment secrets

Store the rover token only in the ignored firmware `secrets.h`. Store the same
token in the ignored Flutter `.env` as `ROVER_TOKEN`. Production actuator
control will also require BLE bonding/encryption and a hardware fail-safe.

This document defines the official communication protocol between the SeedRover mobile application and the ESP32-based robotic system.

All communication between the mobile application and the hardware must follow this specification.

This protocol is designed to remain independent of the communication medium.

Current supported communication methods:

- Wi-Fi
- Bluetooth

Future communication methods:

- LoRa
- MQTT
- Internet

Changing the communication medium must not require changing the message format.

---

# Communication Principles

General Rules

- All communication uses JSON.
- UTF-8 encoding.
- Every message contains a command.
- Every response contains a status.
- Communication must be stateless whenever possible.
- Messages should be concise.
- Unknown commands should never crash the ESP32.
- Invalid requests must return an error response.

---

# Message Format

Every request must follow this structure.

{
    "command": "COMMAND_NAME",
    "timestamp": 1720000000,
    "payload": {
    }
}

Every response must follow this structure.

{
    "status": "success",
    "timestamp": 1720000000,
    "data": {
    }
}

Possible status values

- success
- failed
- invalid_command
- busy
- disconnected

---

# Rover Movement Commands

Forward

Command

MOVE_FORWARD

Payload

{
    "speed": 70
}

Reverse

MOVE_BACKWARD

Left

TURN_LEFT

Right

TURN_RIGHT

Stop

STOP

Notes

Speed ranges from 0 to 100.

---

# Planting Commands

Start planting

START_PLANTING

Pause planting

PAUSE_PLANTING

Resume planting

RESUME_PLANTING

Stop planting

STOP_PLANTING

---

# Camera Commands

Start camera

START_CAMERA

Stop camera

STOP_CAMERA

Refresh stream

REFRESH_CAMERA

---

# Sensor Commands

Request all sensor values

GET_SENSOR_DATA

Expected response

{
    "soil_moisture": 63,
    "soil_temperature": 28,
    "environment_temperature": 31,
    "humidity": 72
}

---

# Robot Status Commands

Request robot status

GET_ROBOT_STATUS

Expected response

{
    "battery_level": 84,
    "seed_level": 67,
    "current_activity": "Planting",
    "wifi_connected": true,
    "bluetooth_connected": false,
    "camera_connected": true,
    "emergency_stop": false
}

---

# Inventory Commands

Request current seed level

GET_SEED_LEVEL

Expected response

{
    "seed_level": 62
}

---

# Emergency Commands

Emergency Stop

EMERGENCY_STOP

Behavior

Immediately stop

- Motors
- Planting mechanism

Sensor monitoring should continue.

---

# Heartbeat

The application should periodically verify that the rover is still connected.

Command

PING

Expected response

PONG

Heartbeat Interval

Every 3 seconds

If three consecutive heartbeat requests fail:

- Mark rover as disconnected.
- Disable rover controls.
- Display reconnect option.

---

# Automatic Updates

The rover should automatically send updated values whenever they change.

Examples

Battery changed

Seed level changed

Current activity changed

Planting started

Planting completed

Emergency stop activated

The mobile application should update only the affected widgets.

---

# Error Responses

Example

{
    "status": "failed",
    "message": "Motor driver unavailable"
}

Never expose internal debugging information to the mobile application.

---

# Connection Priority

Primary

Wi-Fi

Secondary

Bluetooth

If Wi-Fi disconnects while Bluetooth remains connected:

Continue communication through Bluetooth.

The user interface should indicate the active communication method.

---

# Future Expansion

Future versions of this protocol may support

- LoRa
- MQTT
- Multiple rovers
- GPS
- OTA firmware updates

The message format should remain backward compatible whenever possible.

---

# Development Rules

All communication code must be encapsulated inside communication services.

Application widgets must never communicate directly with the ESP32.

Business logic should remain independent of the communication implementation.

The communication protocol should be treated as the single source of truth between the Flutter application and the SeedRover hardware.
