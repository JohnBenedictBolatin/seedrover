#pragma once

// Copy this file to camera_secrets.h. The camera joins the rover network.
const char* ROVER_WIFI_SSID = "SeedRover-01";
// Must exactly match ROVER_TOKEN in the rover's secrets.h and the Flutter app.
const char* ROVER_WIFI_PASSWORD = "replace-with-a-unique-token-8-to-63-chars";

// Optional secondary router fallback for bench/lab testing (matching rover STA credentials).
const char* FALLBACK_WIFI_SSID = "YOUR_ROUTER_SSID";
const char* FALLBACK_WIFI_PASSWORD = "YOUR_ROUTER_PASSWORD";
