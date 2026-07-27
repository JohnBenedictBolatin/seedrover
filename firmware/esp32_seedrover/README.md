# ESP32 Phase 1 — Direct SoftAP PING

The ESP32 creates a WPA2 Wi-Fi network named `SeedRover-01`. The Android phone
connects directly to it and sends local HTTP requests to `192.168.4.1`;
internet access is not required for PING.

## Configure the ESP32

Copy `secrets.example.h` to `secrets.h` and set a token between 8 and 63
characters. The same value secures both the Wi-Fi network and rover API:

```cpp
#pragma once
const char* ROVER_TOKEN = "your-private-rover-token";
```

Install `esp32 by Espressif Systems` through Arduino Boards Manager and
`ArduinoJson by Benoit Blanchon` through Library Manager. Select `DOIT ESP32
DEVKIT V1`, upload `esp32_seedrover.ino`, and open Serial Monitor at 115200.

The ESP32 prints:

```text
Network name: SeedRover-01
Wi-Fi password: use the same value as ROVER_TOKEN
ESP32 address: http://192.168.4.1
```

## Configure the app

Put the SoftAP address and same token in the Flutter app's real `.env`:

```env
ROVER_BASE_URL=http://192.168.4.1
ROVER_TOKEN=your-private-rover-token
```

Rebuild the Android app, connect the phone to `SeedRover-01`, and choose **Stay
connected** if Android warns that the network has no internet. Open Rover
Control, select `Connect Wi-Fi`, and then select `PING`.

The firmware includes a SoftAP watchdog. If the phone disconnects and does not
reconnect within five seconds, the ESP32 restarts only its Wi-Fi access point
so `SeedRover-01` becomes discoverable again. If SoftAP cannot start, the ESP32
performs a controlled reboot as a final recovery path; enclosure access should
not normally be required.

PING plus movement, soil-check, planting, and emergency-stop commands are
acknowledged and printed in Serial Monitor for integration testing. These
commands are simulation-only: this firmware contains no motor, planting, or
actuator GPIO code.
