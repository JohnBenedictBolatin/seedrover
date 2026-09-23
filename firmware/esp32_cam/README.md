# AI-Thinker ESP32-CAM

This camera joins the main rover ESP32 hotspot instead of creating a second
hotspot. The rover remains `SeedRover-01` at `192.168.4.1`; the camera uses the
static address `192.168.4.2`.

Before uploading:

1. Copy `camera_secrets.example.h` to `camera_secrets.h`.
2. Set `ROVER_WIFI_PASSWORD` to the same value as `ROVER_TOKEN` in the rover
   firmware's `secrets.h`.
3. In Arduino IDE select **AI Thinker ESP32-CAM**.
4. Upload using a USB-to-serial adapter. Hold **GPIO 0 to GND** while starting
   the upload, then disconnect GPIO 0 from GND and reset the board.

Endpoints after the camera joins the rover hotspot:

- `http://192.168.4.2/` camera test page
- `http://192.168.4.2/stream` MJPEG stream
- `http://192.168.4.2/capture` single JPEG frame
- `http://192.168.4.2/status` camera status

The camera needs a stable 5V supply capable of roughly 500 mA. Do not power it
from a weak 3.3V logic pin.
