# AI-Thinker ESP32-CAM

This camera joins the main rover ESP32 hotspot instead of creating a second
hotspot. The rover remains `SeedRover-01` at `192.168.4.1`; the camera uses the
static address `192.168.4.2`. The rover's phone DHCP pool starts at
`192.168.4.10` so clients cannot be assigned the camera's address.

Before uploading:

1. Copy `camera_secrets.example.h` to `camera_secrets.h`.
2. Set `ROVER_WIFI_PASSWORD` to the same unique 8-63 character value as
   `ROVER_TOKEN` in the rover firmware's `secrets.h` and the Flutter app's
   `ROVER_TOKEN` setting. The SSID must remain `SeedRover-01`.
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
