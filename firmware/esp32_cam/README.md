# AI-Thinker ESP32-CAM (SeedRover Subsystem)

The ESP32-CAM operates as an independent client node on the SeedRover network. It joins the main rover ESP32 SoftAP hotspot (`SeedRover-01`) instead of creating a conflicting second hotspot.

## Network Architecture & IP Allocation

- **SeedRover AP (Main ESP32):** `192.168.4.1` (Gateway / DNS)
- **ESP32-CAM (Static Client):** `192.168.4.2` (Subnet `255.255.255.0`, Channel 1)
- **Mobile Phone / Tablet Clients:** DHCP assigned starting at `192.168.4.10+`

This guarantees that DHCP clients on the rover hotspot will never collide with the camera's static IP.

## Key Connection Features & System Alignment

1. **Direct Channel 1 Association:** Connects directly to the rover's SoftAP on Channel 1 without running full 13-channel scans, speeding up association to <500ms.
2. **Instant Stream Teardown:** The stream loop checks write bytes on every frame. When the user navigates away, the socket is immediately released so new connections connect without delay.
3. **Modem Sleep Disabled (`WiFi.setSleep(false)`):** Aligned with the rover ESP32 to prevent packet latency, frame drops, and stream stutter.
4. **Brownout Detector Protection:** Software brownout detector is disabled at boot to prevent reboot loops during high-current RF transmission bursts.
5. **Optimized TX Power (`17dBm`):** Matches rover transmission power and prevents voltage sag on the 5V logic rail.
6. **Non-blocking Reconnect Loop:** Uses non-blocking interval monitoring (`monitorCameraWifi()`) matching `monitorRoverWifi()` in `esp32_seedrover.ino`.
7. **PSRAM Double Buffering:** Automatically uses `FRAMESIZE_VGA` and `CAMERA_GRAB_LATEST` with 2 frame buffers when PSRAM is detected, providing zero-lag video feedback during rover navigation.
8. **Built-in Status LED (GPIO 33):**
   - **Blinking:** Connecting or retrying connection.
   - **Solid ON:** Successfully connected to the rover network.
9. **Secrets:**
   - Configure `camera_secrets.h`, or deliberately include the rover's `ROVER_TOKEN` from its local secrets header.
   - Optional router fallback credentials belong in the ignored local secrets header; no working credentials are embedded in source.

## Upload & Setup Guide

1. Ensure local `camera_secrets.h` is present (or `firmware/esp32_seedrover/secrets.h` contains the shared `ROVER_TOKEN`). The sample header is only a template.
2. In Arduino IDE:
   - Select Board: **AI Thinker ESP32-CAM**
   - Flash Frequency: **40MHz**
   - Partition Scheme: **Huge APP (3MB No OTA / 1MB SPIFFS)**
   - PSRAM: **Enabled**
3. Upload using a 3.3V/5V USB-to-UART adapter:
   - Connect `U0R` $\rightarrow$ `TXD`, `U0T` $\rightarrow$ `RXD`, `GND` $\rightarrow$ `GND`, `5V` $\rightarrow$ `5V`.
   - Bridge **GPIO 0 to GND** while pressing RESET or powering on to enter bootloader mode.
   - Click Upload in Arduino IDE.
   - **CRITICAL:** When upload completes, **disconnect GPIO 0 from GND** and press RESET. (Leaving GPIO 0 grounded keeps the ESP32 in bootloader mode, preventing the firmware from starting).

## HTTP Endpoints

| Endpoint | Method | Description |
| :--- | :---: | :--- |
| `http://192.168.4.2/` | `GET` | Camera live preview and diagnostic HTML page |
| `http://192.168.4.2/stream` | `GET` | MJPEG multipart video stream (used by mobile app) |
| `http://192.168.4.2/capture` | `GET` | Single JPEG snapshot |
| `http://192.168.4.2/status` | `GET` | JSON status with RSSI and stream URL |
| `http://192.168.4.2/health` | `GET` | JSON health check (returns `camera_ready`, `psram`, and uptime) |

## Power Requirements

The ESP32-CAM requires a clean, regulated **5.0V DC** supply capable of supplying at least **500 mA** peak (such as the Clean Logic Rail from Buck 2). Do not power it from an ESP32 3.3V pin or an unshielded motor power rail. If brownout resets still occur on battery power, place a $100\mu\text{F} \text{ to } 470\mu\text{F}$ capacitor across `5V` and `GND`.
