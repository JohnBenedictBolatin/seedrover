#include <ESP32Servo.h>

// Seed Gate Servo Pins (matches SeedRover configuration)
#define SERVO_SEED_1_PIN 27     // Seed Gate 1 (Default / Calamansi)
#define SERVO_SEED_2_PIN 4      // Seed Gate 2 (Sitaw)
#define SERVO_SEED_3_PIN 23     // Seed Gate 3 (Peanut)

// Standard Rover angles
const int SEED_CLOSED = 150;
const int SEED_OPEN = 90;

Servo servo1;
Servo servo2;
Servo servo3;

bool autoCycle = false;
unsigned long lastCycleStep = 0;
int cycleStage = 0;

void printMenu() {
  Serial.println("\n============================================");
  Serial.println("   ESP32 SeedRover 3-Servo Dispenser Test   ");
  Serial.println("============================================");
  Serial.println("Pins: Gate 1 = GPIO 27 | Gate 2 = GPIO 4 | Gate 3 = GPIO 23");
  Serial.println("Angles: OPEN = 90 deg | CLOSED = 150 deg");
  Serial.println("--------------------------------------------");
  Serial.println("Commands:");
  Serial.println(" [1] Test Gate 1 (Open -> 1.5s -> Close)");
  Serial.println(" [2] Test Gate 2 (Open -> 1.5s -> Close)");
  Serial.println(" [3] Test Gate 3 (Open -> 1.5s -> Close)");
  Serial.println(" [o] OPEN all gates (90 deg)");
  Serial.println(" [c] CLOSE all gates (150 deg)");
  Serial.println(" [a] Start / Stop Auto-Cycle loop");
  Serial.println(" [s] Sweep test 0 -> 180 -> 0 deg on all servos");
  Serial.println(" [m] Show this menu again");
  Serial.println("============================================");
  Serial.print("Enter command: ");
}

void testSingleGate(int gateNum, Servo &servo, int pin) {
  Serial.printf("\n--> Testing Gate %d (GPIO %d)...\n", gateNum, pin);
  Serial.printf("  Opening Gate %d to %d deg...\n", gateNum, SEED_OPEN);
  servo.write(SEED_OPEN);
  delay(1500);
  Serial.printf("  Closing Gate %d to %d deg...\n", gateNum, SEED_CLOSED);
  servo.write(SEED_CLOSED);
  delay(500);
  Serial.printf("  Gate %d test complete.\n", gateNum);
}

void openAllGates() {
  Serial.printf("\n--> Opening all gates to %d deg...\n", SEED_OPEN);
  servo1.write(SEED_OPEN);
  servo2.write(SEED_OPEN);
  servo3.write(SEED_OPEN);
}

void closeAllGates() {
  Serial.printf("\n--> Closing all gates to %d deg...\n", SEED_CLOSED);
  servo1.write(SEED_CLOSED);
  servo2.write(SEED_CLOSED);
  servo3.write(SEED_CLOSED);
}

void sweepServos() {
  Serial.println("\n--> Running Smooth Sweep Test (0 -> 180 -> 0 deg)...");
  Serial.println("Check for mechanical binding or jitter!");

  for (int pos = 0; pos <= 180; pos += 2) {
    servo1.write(pos);
    servo2.write(pos);
    servo3.write(pos);
    delay(15);
  }
  delay(500);
  for (int pos = 180; pos >= 0; pos -= 2) {
    servo1.write(pos);
    servo2.write(pos);
    servo3.write(pos);
    delay(15);
  }
  delay(500);
  closeAllGates();
  Serial.println("--> Sweep complete. All gates returned to CLOSED.");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n[SETUP] Initializing ESP32 PWM channels for servos...");

  // Standard 50Hz PWM for hobby servos
  servo1.setPeriodHertz(50);
  servo2.setPeriodHertz(50);
  servo3.setPeriodHertz(50);

  // Attach servos with 500us - 2400us pulse width
  servo1.attach(SERVO_SEED_1_PIN, 500, 2400);
  servo2.attach(SERVO_SEED_2_PIN, 500, 2400);
  servo3.attach(SERVO_SEED_3_PIN, 500, 2400);

  // Move all to default closed position on boot
  closeAllGates();

  printMenu();
}

void handleAutoCycle() {
  if (!autoCycle) return;

  const unsigned long now = millis();
  if (now - lastCycleStep < 1200) return;
  lastCycleStep = now;

  switch (cycleStage) {
    case 0:
      Serial.println("[AUTO-CYCLE] Gate 1 OPEN");
      servo1.write(SEED_OPEN);
      cycleStage++;
      break;
    case 1:
      Serial.println("[AUTO-CYCLE] Gate 1 CLOSE");
      servo1.write(SEED_CLOSED);
      cycleStage++;
      break;
    case 2:
      Serial.println("[AUTO-CYCLE] Gate 2 OPEN");
      servo2.write(SEED_OPEN);
      cycleStage++;
      break;
    case 3:
      Serial.println("[AUTO-CYCLE] Gate 2 CLOSE");
      servo2.write(SEED_CLOSED);
      cycleStage++;
      break;
    case 4:
      Serial.println("[AUTO-CYCLE] Gate 3 OPEN");
      servo3.write(SEED_OPEN);
      cycleStage++;
      break;
    case 5:
      Serial.println("[AUTO-CYCLE] Gate 3 CLOSE");
      servo3.write(SEED_CLOSED);
      cycleStage = 0;
      break;
  }
}

void loop() {
  handleAutoCycle();

  if (Serial.available() > 0) {
    char cmd = Serial.read();

    // Ignore newline / carriage return
    if (cmd == '\r' || cmd == '\n') return;

    Serial.println(cmd);

    switch (cmd) {
      case '1':
        autoCycle = false;
        testSingleGate(1, servo1, SERVO_SEED_1_PIN);
        break;
      case '2':
        autoCycle = false;
        testSingleGate(2, servo2, SERVO_SEED_2_PIN);
        break;
      case '3':
        autoCycle = false;
        testSingleGate(3, servo3, SERVO_SEED_3_PIN);
        break;
      case 'o':
      case 'O':
        autoCycle = false;
        openAllGates();
        break;
      case 'c':
      case 'C':
        autoCycle = false;
        closeAllGates();
        break;
      case 's':
      case 'S':
        autoCycle = false;
        sweepServos();
        break;
      case 'a':
      case 'A':
        autoCycle = !autoCycle;
        lastCycleStep = millis();
        cycleStage = 0;
        if (autoCycle) {
          Serial.println("\n--> [AUTO-CYCLE] Started! Servos will open and close in sequence. Send 'a' to stop.");
        } else {
          closeAllGates();
          Serial.println("\n--> [AUTO-CYCLE] Stopped. All gates closed.");
        }
        break;
      case 'm':
      case 'M':
        printMenu();
        break;
      default:
        Serial.printf("Unknown command '%c'. Type 'm' for menu.\n", cmd);
        break;
    }
    Serial.print("\nEnter command: ");
  }
}
