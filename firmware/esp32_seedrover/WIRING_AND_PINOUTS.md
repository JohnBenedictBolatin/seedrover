# SeedRover Pinning, Voltage Levels & Master Wiring Schematic

**System:** SeedRover Autonomous Precision Planting Robot  
**Firmware Target:** `esp32_seedrover.ino` (v3.1.0-raking-scout-planting) & `esp32_cam.ino`  
**Microcontroller:** ESP32-WROOM-32 (30-pin & 38-pin DevKit V1)  
**Document Revision:** 2.0 (Engineering Complete)  
**Status:** Approved for Hardware Assembly & Field Deployment  

---

## 1. System Overview & Architecture Philosophy

The SeedRover electrical architecture is designed for field reliability in harsh agricultural environments (dirt, vibration, moisture). It enforces **strict power domain isolation** between high-current inductive actuators (DC drive gearmotors, high-torque servos) and sensitive logic microcontrollers (ESP32-WROOM-32, AI-Thinker ESP32-CAM, analog soil sensors).

### Core Electrical Design Rules:
1. **Separation of Inductive and Logic Power:** Under heavy load or stall, motors and servos induce high back-EMF spikes and rail voltage drops. The system separates power distribution into four isolated voltage rails.
2. **Unified Star Grounding:** All grounds converge at a single central ground bus terminal to eliminate ground loops and ADC measurement offsets.
3. **Strict 3.3V Logic Level Protection:** The ESP32 GPIOs are **NOT 5V-tolerant** (absolute maximum rating is 3.6V). All 5V output signals (e.g., HC-SR04 ultrasonic echo pulses) must pass through voltage divider networks before reaching the microcontroller.
4. **Modular Keyed Harnesses:** All subsystems interface via keyed quick-disconnect connectors (JST-XH and screw terminals) so any module can be detached, serviced, or bench-tested independently.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   11.1V – 12.6V 3S Li-ion Battery Pack                 │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                            [ 7.5A Fuse & Switch ]
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       │ (12V High-Current Rail)    │ (12V In)                   │ (12V In)
       ▼                            ▼                            ▼
┌──────────────┐         ┌────────────────────┐       ┌────────────────────┐
│ L298N Driver │         │ Buck Converter 1   │       │ Buck Converter 2   │
│ (VMS Input)  │         │ (12V -> 5.5V @ 5A) │       │ (12V -> 5.0V @ 2A) │
└──────┬───────┘         └─────────┬──────────┘       └─────────┬──────────┘
       │                           │                            │
       │ DC Motors                 │ 5.5V Servo Bus             │ 5.0V Clean Logic
       │ (4WD Wheels)              │ (8 Actuators + Cap)        │ (ESP32 VIN, CAM, HC-SR04)
       │                           │                            │
       │                           │                            ├──────────────┐
       │                           │                            ▼              ▼
       │                           │                     ┌───────────┐  ┌──────────────┐
       │                           │                     │ ESP32 VIN │  │ ESP32-CAM 5V │
       │                           │                     └─────┬─────┘  └──────────────┘
       │                           │                           │ (Onboard 3.3V LDO)
       │                           │                           ▼
       │                           │                     ┌────────────────────────┐
       │                           │                     │ Clean 3.3V Sensor Rail │
       │                           │                     │ (Soil ADC, DS18B20,    │
       │                           │                     │  DHT11 Data Pull-ups)  │
       │                           │                     └────────────────────────┘
       │                           │                                │
       └───────────────────────────┼────────────────────────────────┘
                                   │
                     ★ Central Star Ground (GND)
```

---

## 2. Power Distribution & Voltage Domains

| Voltage Rail | Nominal Voltage | Operating Range | Max Current | Source | Destination Loads | Wire Gauge (AWG) |
| :--- | :---: | :---: | :---: | :--- | :--- | :---: |
| **Raw Battery Rail** | **12.0 V** | 11.1V – 12.6V | 7.5A (Fused) | 3S Li-ion / LiPo Pack | L298N Motor Driver (`VMS`), Buck 1 In, Buck 2 In | **16 – 18 AWG** |
| **Servo Actuator Rail** | **5.5 V** | 5.3V – 5.6V | 5.0A Cont. / 7A Peak | Buck 1 (XL4015 / High-Amp Buck) | 8x Servos (3x Gates, 1x Tube, 1x Rake, 1x Leveler, 1x Molder, 1x Probe) | **18 – 20 AWG** |
| **Clean Logic Rail** | **5.0 V** | 4.9V – 5.1V | 2.0A Regulated | Buck 2 (LM2596 / MP1584 Buck) | ESP32 `VIN`, ESP32-CAM `5V`, 2x HC-SR04 `VCC` | **22 AWG** |
| **Sensor Reference Rail** | **3.3 V** | 3.25V – 3.35V | 500mA | ESP32 Onboard LDO (`3V3` Pin) | Soil Moisture Sensor `VCC`, DS18B20 `VDD`, DHT11 `VCC`, Signal Pull-ups | **24 – 26 AWG** |
| **Common Star Ground** | **0.0 V** | 0.0V Reference | 10A Return | Star Terminal Ground Block | Unified return for all batteries, converters, and modules | **16 AWG** |

> **Critical Power Rules:**
> 1. **Do not power servos from the ESP32 5V or 3.3V pins.** Servos under load draw over 1.5A stall current and will burn out the onboard regulator or cause CPU resets.
> 2. **Place a 1000 µF 16V electrolytic capacitor** across the 5.5V Servo Rail to absorb transient current surges.
> 3. **Keep Star Grounding clean:** Route motor high-current ground directly back to the battery return terminal, not through the ESP32 board.

---

## 3. Voltage Levels & Logic Compatibility Matrix

The ESP32 microcontroller operates strictly at **3.3V CMOS logic**:
- **Output High Voltage ($V_{OH}$):** $\ge 2.64\text{ V}$ (typically $3.3\text{ V}$)
- **Output Low Voltage ($V_{OL}$):** $\le 0.33\text{ V}$ (typically $0.0\text{ V}$)
- **Input High Threshold ($V_{IH}$):** $\ge 2.47\text{ V}$ ($0.75 \times V_{DD}$)
- **Input Low Threshold ($V_{IL}$):** $\le 0.825\text{ V}$ ($0.25 \times V_{DD}$)
- **Absolute Maximum Input Voltage:** **$3.6\text{ V}$** (Exceeding 3.6V will puncture the ESD protection clamp diodes and destroy the silicon pin).

### Detailed Peripheral Compatibility & Signal Treatment

| Component / Pin | Direction | Signal Type | Component Operating VCC | Component Logic Level | ESP32 GPIO Level | Required Interface / Signal Treatment |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **L298N Motor Inputs** (`IN1`–`IN4`) | ESP32 $\rightarrow$ Driver | Digital Out | 5.0V / 12V | $V_{IH, min} = 2.3\text{ V}$ | 3.3V Output | **Direct Connection.** ESP32 3.3V High exceeds the L298N 2.3V threshold. |
| **PWM Servos (x8)** | ESP32 $\rightarrow$ Servo | PWM Out (50Hz) | 5.5V Servo Rail | $V_{IH, min} \approx 2.0\text{ V} - 2.4\text{ V}$ | 3.3V PWM Output | **Direct Connection.** Standard RC servos recognize 3.3V pulses as valid HIGH logic. |
| **HC-SR04 `TRIG`** (Front & Rear) | ESP32 $\rightarrow$ Sensor | Digital Out | 5.0V Clean Rail | $V_{IH, min} = 2.0\text{ V}$ | 3.3V Output | **Direct Connection.** Sensor reliably triggers on 3.3V 10µs pulse. |
| **HC-SR04 `ECHO`** (Front & Rear) | Sensor $\rightarrow$ ESP32 | Digital In | 5.0V Clean Rail | 5.0V Output High ($V_{OH} \approx 5.0\text{ V}$) | **3.3V Input Max** | **MANDATORY Voltage Divider (1.0 kΩ / 2.0 kΩ).** Steps 5V down to 3.33V. |
| **Capacitive Soil Sensor** | Sensor $\rightarrow$ ESP32 | Analog In | 3.3V Sensor Rail | 0.0V – 3.0V Analog | ADC1 (0.0V – 3.3V) | **Direct Connection to GPIO 34.** Powered from 3.3V so output never exceeds 3.3V. |
| **DS18B20 Temp Probe** | Bidirectional | OneWire | 3.3V Sensor Rail | 3.3V Open-Drain | 3.3V Bidirectional | **4.7 kΩ Pull-Up Resistor to 3.3V Rail.** (NEVER pull up to 5V!). |
| **DHT11 Air Sensor** | Bidirectional | 1-Wire Single Bus | 3.3V Sensor Rail | 3.3V Open-Drain | 3.3V Bidirectional | **10 kΩ Pull-Up Resistor to 3.3V Rail.** |
| **AI-Thinker ESP32-CAM** | Independent Node | Wi-Fi Client | 5.0V Clean Rail | 3.3V Internal | SoftAP Network | **No wired GPIO data link.** Communicates over Rover Wi-Fi SoftAP at `192.168.4.2`. |

---

## 4. Signal Conditioning & Level Shifter Circuits

### 4.1. Ultrasonic ECHO 5V-to-3.3V Voltage Divider

The HC-SR04 ultrasonic echo pulse outputs **5.0V**. Connecting this directly to ESP32 GPIO 15 or GPIO 17 will over-voltage and degrade or kill the GPIO. A precision resistive divider is required:

```
                      R1 = 1.0 kΩ (1%)
HC-SR04 ECHO (5V) ───────────[====]───────────┬───────────> To ESP32 GPIO (3.3V Safe)
                                              │
                                              │
                                           [====] R2 = 2.0 kΩ (1%)
                                              │
                                              │
                                             GND (Common Star Ground)
```

#### Calculation & Safety Margin:
$$V_{out} = V_{in} \times \left( \frac{R_2}{R_1 + R_2} \right) = 5.0\text{ V} \times \left( \frac{2000}{1000 + 2000} \right) = 5.0\text{ V} \times \frac{2}{3} = 3.333\text{ V}$$

- $3.333\text{ V}$ is comfortably below the ESP32 absolute maximum rating of $3.6\text{ V}$.
- Standard resistor substitution: If a $2.0\text{ k}\Omega$ resistor is unavailable, use **two $1.0\text{ k}\Omega$ resistors in series** for $R_2$, or use **$R_1 = 2.2\text{ k}\Omega$ and $R_2 = 3.3\text{ k}\Omega$** ($V_{out} = 3.00\text{ V}$).

---

### 4.2. Sensor Pull-Up Circuits

Both the **DS18B20** and **DHT11** use open-drain/single-bus protocols requiring external pull-up resistors to maintain a default HIGH bus state:

```
  +3.3V Sensor Rail ────────┬─────────────────────────┬───────────────
                            │                         │
                         [ 4.7 kΩ ]                [ 10 kΩ ]
                         Pull-Up                   Pull-Up
                            │                         │
  GPIO 14 (OneWire) ────────┴─────> DS18B20 Data      │
                                                      │
  GPIO 25 (DHT11)   ──────────────────────────────────┴─────> DHT11 Data
```

> **Warning:** Do NOT connect the pull-up resistors to 5.0V! Even though DS18B20 sensors can tolerate 5V power, pulling the data line up to 5V exposes GPIO 14 to destructive 5V logic. **Always tie pull-ups to the 3.3V rail.**

---

### 4.3. Analog Soil Sensor & ADC Pin Selection

- **Pin Used:** `GPIO 34` (`SOIL_SENSOR_PIN`).
- **ADC Group:** **ADC1** (Channel `ADC1_CH6`).
- **Why ADC1 is strictly mandatory:** In the ESP32 architecture, **ADC2 is multiplexed with the internal Wi-Fi and Bluetooth radio**. When the ESP32 operates its SoftAP (`SeedRover-01`) or joins Wi-Fi, the Wi-Fi driver asserts control of ADC2, returning erratic values or `0` on any ADC2 pin (GPIOs 0, 2, 4, 12, 13, 14, 15, 25, 26, 27). **GPIO 34 belongs to ADC1**, which is completely independent of the radio and reads analog voltages reliably at all times.
- **Input Voltage Range:** Sensor VCC is powered from 3.3V. Its analog output ranges between 0.8V (fully submerged in saturated mud) and 3.0V (bone dry in air), fitting safely within the ESP32 ADC 11dB attenuation full-scale range (0 – 3.3V).

---

## 5. Master System Schematic Diagram

```
                                 +-------------------------+
                                 |  3S Li-ion Battery Pack |
                                 |     11.1V - 12.6V       |
                                 +------------+------------+
                                              |
                                      [ 7.5A FUSE & SWITCH ]
                                              |
      +---------------------------------------+---------------------------------------+
      | (12V High Current)                    | (12V Input)                           | (12V Input)
      |                                       v                                       v
      |                             +--------------------+                  +--------------------+
      |                             |   BUCK 1 (XL4015)  |                  |   BUCK 2 (LM2596)  |
      |                             |  12V -> 5.5V @ 5A  |                  |  12V -> 5.0V @ 2A  |
      |                             +---------+----------+                  +---------+----------+
      |                                       |                                       |
      |                                       | 5.5V Servo Bus                        | 5.0V Logic Bus
      |                                       |                                       +----------------+
      v                                       |                                       |                |
+--------------+                              |                                       v                v
| L298N DRIVER |                              |                                  +---------+     +------------+
| 12V (VMS)    |                              |                                  | ESP32   |     | ESP32-CAM  |
| GND          |                              |                                  | (VIN)   |     | (5V Pin)   |
+---+--+--+--+-+                              |                                  +----+----+     +-----+------+
    |  |  |  |                                |                                       |                |
    |  |  |  |                                |                                       v (3.3V LDO)     |
    |  |  |  |                                |                                  +----+----+           |
    |  |  |  |                                |                                  |  3.3V   |           |
    |  |  |  |    +---------------------------+-----------+                      +----+----+           |
    |  |  |  |    | 1000 µF / 16V Decoupling Capacitor    |                           |                |
    |  |  |  |    +---------------------------------------+                           |                |
    |  |  |  |    | 5.5V VCC to All 8 Servos              |                           |                |
    |  |  |  |    |                                       |                           |                |
    |  |  |  |    +--> Gate 1 Servo (Calamansi)           |                           |                |
    |  |  |  |    +--> Gate 2 Servo (Sitaw)               |                           |                |
    |  |  |  |    +--> Gate 3 Servo (Peanut)              |                           |                |
    |  |  |  |    +--> Punch/Drop Tube Servo              |                           |                |
    |  |  |  |    +--> Rake / Furrow Servo                |                           |                |
    |  |  |  |    +--> Soil Leveler Servo                 |                           |                |
    |  |  |  |    +--> Soil Molder Servo                  |                           |                |
    |  |  |  |    +--> Soil Probe Deploy Servo            |                           |                |
    |  |  |  |                                            |                           |                |
    v  v  v  v                                            v                           v                v
  LEFT & RIGHT                                       SERVO PWM                    SENSORS          GROUND RETURN
  DRIVE MOTORS                                       SIGNALS                     (MOISTURE, TEMP)
    ^  ^  ^  ^                                            ^                           ^                ^
    |  |  |  |                                            |                           |                |
+---+--+--+--+--------------------------------------------+---------------------------+----------------+---+
|  18 19 21 22   27     4     23     2      26     32     33     13      34     14     25     5    15  16  17  |
|  IN1-IN4 PWM  GATE1 GATE2 GATE3  TUBE    RAKE  LEVEL   MOLD  PROBE    SOIL   TEMP   DHT11   TRIG ECHO TRIG ECHO |
|                                                                       ADC   DS18B20        FRONT ARRAY  REAR   |
|                                     ESP32-WROOM-32 CONTROLLER                                     |   |   |   |
|                                                                                                   | [DIV] | [DIV]
+---------------------------------------------------------------------------------------------------+---+---+---+--+
                                                                                                    |   |   |   |
                                                                                                    v   v   v   v
                                                                                                  +---------------+
                                                                                                  | HC-SR04 ARRAY |
                                                                                                  | Front & Rear  |
                                                                                                  +---------------+
```

---

## 6. Complete ESP32 Master Pin Assignment Table

Below is the definitive pin-by-pin mapping corresponding to `esp32_seedrover.ino`:

| ESP32 GPIO | 30-Pin Board Pin | 38-Pin Board Pin | Firmware Constant | Direction | Logic Level | Subsystem & Function | Signal Conditioning / Protection |
| :---: | :---: | :---: | :--- | :---: | :---: | :--- | :--- |
| **GPIO 2** | D2 | GPIO2 | `SERVO_SEED_TUBE_PIN` | Output (PWM) | 3.3V PWM | *(Retired / Unpopulated)* Hole Punch & Seed Drop Tube Servo | Retired from robot build (flash dispensing replaces tube punch). Strapping pin. |
| **GPIO 4** | D4 | GPIO4 | `SERVO_SEED_2_PIN` | Output (PWM) | 3.3V PWM | **Seed Gate 2 Servo** (Sitaw / Long Bean) | Standard IO. Direct PWM connection. |
| **GPIO 5** | D5 | GPIO5 | `FRONT_ULTRASONIC_TRIG_PIN` | Output | 3.3V Logic | **Front Ultrasonic Trigger Pulse** | Strapping pin (driven `LOW` immediately in `setup()`). |
| **GPIO 13** | D13 | GPIO13 | `SERVO_SOIL_SENSOR_PIN` | Output (PWM) | 3.3V PWM | **Soil Sensor Deployment Arm Servo** | Standard IO. Direct PWM connection. |
| **GPIO 14** | D14 | GPIO14 | `TEMP_SENSOR_PIN` | In / Out | 3.3V OneWire | **DS18B20 Digital Soil Temp Probe** | **Requires 4.7 kΩ pull-up to 3.3V Rail**. |
| **GPIO 15** | D15 | GPIO15 | `FRONT_ULTRASONIC_ECHO_PIN` | Input | 3.3V Scaled | **Front Ultrasonic Echo Pulse** | **Requires 1.0k / 2.0k divider from 5V Echo**. Strapping pin. |
| **GPIO 16** | RX2 | GPIO16 | `REAR_ULTRASONIC_TRIG_PIN` | Output | 3.3V Logic | **Rear Ultrasonic Trigger Pulse** | Standard IO. Direct connection. |
| **GPIO 17** | TX2 | GPIO17 | `REAR_ULTRASONIC_ECHO_PIN` | Input | 3.3V Scaled | **Rear Ultrasonic Echo Pulse** | **Requires 1.0k / 2.0k divider from 5V Echo**. |
| **GPIO 18** | D18 | GPIO18 | `IN1` | Output | 3.3V Logic | **L298N Left Motor Forward** | Direct connection to driver terminal `IN1`. |
| **GPIO 19** | D19 | GPIO19 | `IN2` | Output | 3.3V Logic | **L298N Left Motor Reverse** | Direct connection to driver terminal `IN2`. |
| **GPIO 21** | D21 | GPIO21 | `IN3` | Output | 3.3V Logic | **L298N Right Motor Forward** | Direct connection to driver terminal `IN3`. |
| **GPIO 22** | D22 | GPIO22 | `IN4` | Output | 3.3V Logic | **L298N Right Motor Reverse** | Direct connection to driver terminal `IN4`. |
| **GPIO 23** | D23 | GPIO23 | `SERVO_SEED_3_PIN` | Output (PWM) | 3.3V PWM | **Seed Gate 3 Servo** (Peanut / Large Seed) | Standard IO. Direct PWM connection. |
| **GPIO 25** | D25 | GPIO25 | `DHT_SENSOR_PIN` | In / Out | 3.3V 1-Wire | **DHT11 Air Temp & Humidity Data** | **Requires 10 kΩ pull-up to 3.3V Rail**. |
| **GPIO 26** | D26 | GPIO26 | `SERVO_SOIL_MECH_PIN` | Output (PWM) | 3.3V PWM | **Soil Rake / Furrow Opener Servo** | Standard IO. Direct PWM connection. Raised: 0°, Open: 20°. |
| **GPIO 27** | D27 | GPIO27 | `SERVO_SEED_1_PIN` | Output (PWM) | 3.3V PWM | **Seed Gate 1 Servo** (Calamansi / Default) | Standard IO. Direct PWM connection. |
| **GPIO 32** | D32 | GPIO32 | `SERVO_LEVELER_PIN` | Output (PWM) | 3.3V PWM | *(Retired / Unpopulated)* Soil Leveler / Smoother Servo | Retired from robot build (legacy alias retained in firmware). |
| **GPIO 33** | D33 | GPIO33 | `SERVO_FLATTENER_PIN` | Output (PWM) | 3.3V PWM | **Soil Flattener Servo** (flattens soil after being raked) | Standard IO. Direct PWM connection. Raised: 90°, Flat: 140°. |
| **GPIO 34** | D34 | GPIO34 | `SOIL_SENSOR_PIN` | Input Only | 0 – 3.0V Analog | **Capacitive Soil Moisture Analog In** | **ADC1_CH6 (Wi-Fi safe)**. Input-only pin. |
| **VIN** | VIN | VIN | — | Power In | 5.0 V DC | **ESP32 Core Power Input** | Direct from Buck 2 (clean 5.0V @ 2A). |
| **3V3** | 3V3 | 3V3 | — | Power Out | 3.3 V DC | **Clean Sensor Power Out** | Onboard LDO output to low-current sensors. |
| **GND** | GND | GND | — | Power | 0.0 V (Ground) | **System Common Ground** | Connected to Star Ground Terminal Block. |

---

## 7. ESP32 Boot Strapping Pins & Engineering Cautions

The ESP32 features several **strapping pins** that dictate chip startup, flashing, and internal flash LDO voltages. Miswiring these pins can prevent the rover from booting:

| Strapping Pin | Normal Boot State Required | Rover Connection | Potential Pitfall & Solution |
| :---: | :---: | :--- | :--- |
| **GPIO 0** | **HIGH (Pull-Up)** | Unconnected on Rover ESP32 (Used on ESP32-CAM for flash mode) | If pulled LOW during power-on, the chip enters ROM bootloader mode instead of executing firmware. Keep floating or pulled HIGH with internal resistor. |
| **GPIO 2** | **LOW or Floating** | Connected to `SERVO_SEED_TUBE_PIN` | Must be LOW to enter UART download mode. The servo signal wire presents high impedance on boot, allowing normal boot sequence. |
| **GPIO 5** | **HIGH (Default)** | Connected to `FRONT_ULTRASONIC_TRIG_PIN` | Outputs PWM timing during boot. Firmware explicitly sets `digitalWrite(FRONT_ULTRASONIC_TRIG_PIN, LOW)` in `setup()` immediately. |
| **GPIO 12 (MTDI)**| **LOW (Must be 0V)** | **DELIBERATELY UNUSED** | **CRITICAL:** If driven HIGH during boot, it switches the internal flash memory voltage from 3.3V to 1.8V, bricking boot. Kept unconnected. |
| **GPIO 15** | **LOW (Default)** | Connected to `FRONT_ULTRASONIC_ECHO_PIN` | Controls boot debug log output on UART0. Because GPIO 15 connects to the voltage divider with $2\text{ k}\Omega$ resistor tied to GND, it is naturally pulled LOW on boot, guaranteeing silent, clean boot. |
| **GPIO 6–11** | **DO NOT USE** | Connected to internal SPI Flash chip | Connected directly to the integrated SPI flash chip. Attempting to use them as GPIOs will immediately crash the MCU. |

---

## 8. Modular Subsystem Harnesses & Connector Pinouts

Each subsystem is isolated via dedicated keyed connectors. This enables fast replacement and isolated bench testing.

```
       ┌────────────────────────────────────────────────────────┐
       │             ROVER HARNESS CONNECTOR SUMMARY            │
       ├──────────┬──────────────────────────┬──────────────────┤
       │ Harness  │ Subsystem                │ Connector Type   │
       ├──────────┼──────────────────────────┼──────────────────┤
       │ **A**    │ Wheel Motors & L298N     │ 6-Pin Terminal   │
       │ **B**    │ Multi-Crop Seed Gates    │ 6-Pin JST-XH     │
       │ **C**    │ Soil Preparation Tools   │ 5-Pin JST-XH     │
       │ **D**    │ Soil & Weather Sensors   │ 7-Pin JST-XH     │
       │ **E**    │ Ultrasonic Dual Array    │ 6-Pin JST-XH     │
       │ **F**    │ AI-Thinker ESP32-CAM     │ 4-Pin JST-XH     │
       └──────────┴──────────────────────────┴──────────────────┘
```

### 8.1. Harness A: Wheel Drive & Motors (6-Pin Screw Terminal / JST-XH)
* **Function:** Transmits motor logic commands from ESP32 to L298N Dual H-Bridge.
* **Driver:** L298N Module.

| Pin # | Harness Label | Function | ESP32 GPIO | Driver Connection | Signal Voltage | Wire Color |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| **1** | `MOT_IN1` | Left Motor Forward | **GPIO 18** | `IN1` | 3.3V Logic | Yellow |
| **2** | `MOT_IN2` | Left Motor Reverse | **GPIO 19** | `IN2` | 3.3V Logic | White |
| **3** | `MOT_IN3` | Right Motor Forward | **GPIO 21** | `IN3` | 3.3V Logic | Green |
| **4** | `MOT_IN4` | Right Motor Reverse | **GPIO 22** | `IN4` | 3.3V Logic | Blue |
| **5** | `GND` | Logic Ground Reference | `GND` | `GND` | 0.0V Ground | Black |
| **6** | `V_RAW` | 12V High-Current Supply | — | `12V / VMS` | 11.1V – 12.6V | Red (16 AWG) |

* **L298N Output Connections:**
  - `OUT1` & `OUT2` $\rightarrow$ Left Wheel Motors (Front-Left & Rear-Left DC gearmotors wired in parallel).
  - `OUT3` & `OUT4` $\rightarrow$ Right Wheel Motors (Front-Right & Rear-Right DC gearmotors wired in parallel).

---

### 8.2. Harness B: Multi-Crop Seed Dispensing (6-Pin Keyed JST-XH)
* **Function:** Operates the three seed dispenser selection gates and the seed hole punch/drop tube.

| Pin # | Harness Label | Subsystem Function | ESP32 Pin | Power Source | Wire Color |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **1** | `5V_SERVO` | Servo Power Rail | — | Buck 1 (5.5V Rail) | Red (18 AWG) |
| **2** | `GND` | Common Ground | `GND` | Star Ground Bus | Black (18 AWG) |
| **3** | `SIG_SEED1` | Seed Gate 1 Servo (Calamansi) | **GPIO 27** | 3.3V PWM (50Hz) | Yellow |
| **4** | `SIG_SEED2` | Seed Gate 2 Servo (Sitaw) | **GPIO 4** | 3.3V PWM (50Hz) | Green |
| **5** | `SIG_SEED3` | Seed Gate 3 Servo (Peanut) | **GPIO 23** | 3.3V PWM (50Hz) | Blue |
| **6** | *(Reserved)* | *(Seed Tube Retired)* | — | — | Unpopulated |

> **Calibrated Seed Hatch Angles & Dispense Timing:**
> - **Gate 1 (Calamansi, GPIO 27):** Default Closed = `90°`, Dispense Open = `60°`
> - **Gate 2 (Sitaw, GPIO 4):** Default Closed = `90°`, Dispense Open = `60°`
> - **Gate 3 (Peanut, GPIO 23):** Default Closed = `85°`, Dispense Open = `55°`
> - **Dispenser Flash Timing:** `1000 ms` (1.0 second flash move open-to-close pulse; no drop tube needed)

---

### 8.3. Harness C: Soil Preparation & Finishing (Keyed JST-XH)
* **Function:** Actuates the soil furrowing rake (furrow tilling pass) and soil flattener (forward planting pass to flatten raked soil with seeds).

| Pin # | Harness Label | Subsystem Function | ESP32 Pin | Power Source | Wire Color |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **1** | `5V_SERVO` | Servo Power Rail | — | Buck 1 (5.5V Rail) | Red (18 AWG) |
| **2** | `GND` | Common Ground | `GND` | Star Ground Bus | Black (18 AWG) |
| **3** | `SIG_RAKE` | Rake / Furrow Opener Servo | **GPIO 26** | 3.3V PWM (50Hz) | Yellow |
| **4** | *(Reserved)* | *(Leveler Retired)* | — | — | Unpopulated |
| **5** | `SIG_FLAT` | Soil Flattener Servo (after rake) | **GPIO 33** | 3.3V PWM (50Hz) | Blue |

> **Calibrated Soil Tool Angles & Autonomous Operation:**
> - **Rake / Furrow Opener (GPIO 26):**
>   - **Default Raised (UP):** `0°` (`soilMechUP` / `rakeDEFAULT`)
>   - **Open / Lowered (DOWN):** `20°` (`soilMechDOWN` / `rakeOPEN`)
> - **Soil Flattener (GPIO 33):**
>   - **Default Raised (UP):** `90°` (`flattenerUP`)
>   - **Flattening DOWN:** `140°` (`flattenerDOWN`)
> - **Operational Logic in Automatic Planting:**
>   1. **Field Distance & Furrow Pass:** Rover drives forward with Rake lowered to `20°` to furrow the soil while the front USDS measures bed length and detects end boundary (`<= 5.0 cm`).
>   2. **Reverse to Origin:** Rake lifts to `0°` (default raised) so it doesn't drag backward. Rover reverses to $0\text{ cm}$.
>   3. **Planting & Flattening Pass:** Rake remains at default `0°`, Flattener lowers to `140°`. Rover moves forward to each divided point, drops seeds into the raked furrow, and the flattener immediately flattens and covers the raked soil with seeds. Row completes at the end of the field.

---

### 8.4. Harness D: Soil & Weather Sensing (7-Pin Keyed JST-XH / GX12)
* **Function:** Interfaces the deployable soil probe (servo + moisture + temp) and the ambient weather sensor.

| Pin # | Harness Label | Sensor / Actuator | ESP32 Pin | Power Rail | Signal Treatment / Notes | Wire Color |
| :---: | :--- | :--- | :---: | :---: | :--- | :---: |
| **1** | `3.3V_SENS` | Clean Sensor VDD | — | ESP32 `3V3` Pin | Dedicated clean sensor supply | Red (24 AWG) |
| **2** | `5V_SERVO` | Probe Deploy Servo Power | — | Buck 1 (5.5V Rail) | High-current actuator rail | Orange |
| **3** | `GND` | Common Ground | `GND` | Star Ground Bus | Shared ground return | Black (20 AWG) |
| **4** | `SIG_PROBE` | Soil Deploy Servo Signal | **GPIO 13** | 3.3V PWM (50Hz) | Direct PWM from ESP32 | Yellow |
| **5** | `SOIL_ADC` | Soil Moisture Analog In | **GPIO 34** | 0.0V – 3.0V Analog | Connects to `ADC1_CH6` (Wi-Fi safe) | Green |
| **6** | `ONEWIRE` | DS18B20 Soil Temp Data | **GPIO 14** | 3.3V OneWire Bus | **4.7 kΩ pull-up to 3.3V Rail** | Blue |
| **7** | `DHT_DATA` | DHT11 Air Temp/Humidity | **GPIO 25** | 3.3V Single-Bus | **10 kΩ pull-up to 3.3V Rail** | White |

---

### 8.5. Harness E: Ultrasonic Distance Array (6-Pin Keyed JST-XH)
* **Function:** Dual HC-SR04 sensors monitoring front field boundaries and rear obstacles.

| Pin # | Harness Label | Sensor Connection | ESP32 Pin | Power Rail | Signal Treatment | Wire Color |
| :---: | :--- | :--- | :---: | :---: | :--- | :---: |
| **1** | `5V_LOGIC` | Ultrasonic VCC (Both Modules) | — | Buck 2 (5.0V Clean) | Transducers require full 5.0V | Red |
| **2** | `GND` | Ultrasonic GND (Both Modules) | `GND` | Star Ground Bus | Common ground | Black |
| **3** | `F_TRIG` | Front HC-SR04 TRIG | **GPIO 5** | 3.3V Output Pulse | Direct 10µs trigger pulse | Yellow |
| **4** | `F_ECHO` | Front HC-SR04 ECHO | **GPIO 15** | 3.3V Scaled Input | **Passes through 1k / 2k Divider** | Green |
| **5** | `R_TRIG` | Rear HC-SR04 TRIG | **GPIO 16** | 3.3V Output Pulse | Direct 10µs trigger pulse | Blue |
| **6** | `R_ECHO` | Rear HC-SR04 ECHO | **GPIO 17** | 3.3V Scaled Input | **Passes through 1k / 2k Divider** | White |

---

### 8.6. Harness F: AI-Thinker ESP32-CAM (4-Pin JST-XH / Direct Header)
* **Function:** Powers the camera module and provides programming access.

| Pin # | Module Pin | Connected To | Voltage Level | Notes |
| :---: | :--- | :--- | :---: | :--- |
| **1** | `5V` | Buck 2 Output | 5.0 V DC | Requires stable ~500mA peak during Wi-Fi transmission. |
| **2** | `GND` | Star Ground Bus | 0.0 V (Ground) | Unified ground. |
| **3** | `U0R` / `U0T` | USB-Serial Programmer | 3.3V UART | Used only during firmware upload. Disconnect in field. |
| **4** | `GPIO 0` | Jumper to GND (flashing only) | 0.0 V (Ground) | Bridge to GND to flash, disconnect for normal boot. |

---

## 9. Wire Gauges & Color Coding Standards

| Wire Gauge | Current Rating | Recommended Circuits |
| :---: | :---: | :--- |
| **16 AWG** | Up to 10 A | Battery positive lead, Main ground bus, 12V motor driver supply |
| **18 AWG** | Up to 6 A | Buck converter 1 output (5.5V Servo rail), Servo ground feeder |
| **20 AWG** | Up to 3.5 A | Buck converter 2 output (5.0V Logic rail), DC motor individual leads |
| **22 – 24 AWG** | Up to 1.5 A | ESP32 power (`VIN`), HC-SR04 supply, Sensor power lines |
| **26 AWG** | Low Current (< 0.5 A) | Logic signals: Servo PWM lines, Ultrasonic TRIG/ECHO, OneWire, I2C |

### Standard Color Conventions:
- **Red:** DC Positive Voltage (+12V, +5.5V, +5.0V)
- **Black:** Common Ground (GND / 0V)
- **Orange / Violet:** 3.3V Regulated Sensor Supply
- **Yellow:** Primary Signal / Actuator Channel 1 (Seed Gate 1, Rake, Front Trig, IN1)
- **Green:** Secondary Signal / Channel 2 (Seed Gate 2, Leveler, Front Echo, IN2, Soil ADC)
- **Blue:** Tertiary Signal / Channel 3 (Seed Gate 3, Molder, Rear Trig, IN3, DS18B20)
- **White:** Quaternary Signal / Auxiliary (Seed Tube, Rear Echo, DHT11, IN4)

---

## 10. Pre-Flight Multimeter Verification & Commissioning

```
Step 1: Check Battery Voltage
        [ DMM on DC Volts ] ---> Battery terminals read 11.1V - 12.6V.

Step 2: Adjust & Verify Buck 1 (Servo Rail)
        [ Multimeter on Buck 1 Output ] ---> Adjust trimpot until output is strictly 5.45V - 5.50V.
        [ CAUTION: Do NOT connect servos yet! ]

Step 3: Adjust & Verify Buck 2 (Logic Rail)
        [ Multimeter on Buck 2 Output ] ---> Adjust trimpot until output is strictly 5.00V - 5.05V.

Step 4: Star Ground Continuity Test
        [ DMM on Resistance / Continuity Mode ]
        Probe between:
        - Battery (-) terminal
        - Buck 1 GND
        - Buck 2 GND
        - L298N GND
        - ESP32 GND
        - Sensor GND
        ---> Reading must be < 0.2 Ω (Dead short / unified ground).

Step 5: Verify Ultrasonic Divider Outputs
        - Temporarily apply 5.0V to HC-SR04 ECHO pin.
        - Measure voltage at GPIO 15 and GPIO 17 test pads on the harness side.
        - Multimeter MUST read between 3.25V and 3.35V.
        ---> If reading is > 3.6V, DO NOT PLUG IN ESP32! Verify 1.0k / 2.0k resistor placement.

Step 6: Verify Pull-Up Voltages
        - Power on ESP32 without DS18B20 or DHT11 connected.
        - Measure DC voltage on GPIO 14 (OneWire) and GPIO 25 (DHT11).
        - Both lines MUST measure exactly 3.3V.

Step 7: Subsystem-by-Subsystem Hot-Plug Testing
        1. Plug in ESP32. Verify blue power LED lights up and SoftAP SeedRover-01 appears on Wi-Fi scan.
        2. Plug in Harness B (Seed Dispenser). Open Serial Monitor at 115200 baud, send 1, 2, 3, t to confirm servo actuation.
        3. Plug in Harness C (Soil Tools). Send rake, leveler, molder in Serial Monitor.
        4. Plug in Harness D (Sensors). Send soil in Serial Monitor. Confirm realistic analog raw value (1500–3500) and temperature reading (~25°C–32°C).
        5. Plug in Harness E (Ultrasonics). Send dist in Serial Monitor. Confirm valid cm distances when an object is held in front and behind.
        6. Plug in Harness A (Drive Motors). Send forward/reverse drive commands and confirm correct wheel rotation direction.
```
