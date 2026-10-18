/*
 * ==============================================================================
 *  SeedRover - Single Servo Serial Calibration (Arduino Uno Version)
 * ==============================================================================
 *  Target Board: Arduino Uno / Nano / Mega
 *  Baud Rate:    115200 (Set Serial Monitor to "Both NL & CR")
 * ==============================================================================
 */

#include <Servo.h>

// Change this pin if you want to test a different servo
#define TEST_SERVO_PIN 4  
#define SERVO_NAME "Seed Gate 2 (Calamansi)"

Servo myServo;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n===========================================");
  Serial.println("     SeedRover Single Servo Tester        ");
  Serial.println("===========================================");

  // Initialize Standard Arduino Servo
  myServo.attach(TEST_SERVO_PIN, 500, 2400);

  // Start at 0 degrees on boot
  myServo.write(0);
  
  Serial.print("[BOOT] ");
  Serial.print(SERVO_NAME);
  Serial.print(" attached to Pin ");
  Serial.println(TEST_SERVO_PIN);
  Serial.println("[BOOT] Initialized to 0 degrees.");
  
  printPrompt();
}

void loop() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();

    if (input.length() > 0) {
      int angle = input.toInt();

      // Validate range (0 to 180 degrees)
      if (angle >= 0 && angle <= 180) {
        myServo.write(angle);
        
        Serial.print("--> Success! Moved ");
        Serial.print(SERVO_NAME);
        Serial.print(" (Pin ");
        Serial.print(TEST_SERVO_PIN);
        Serial.print(") to: ");
        Serial.print(angle);
        Serial.println(" degrees");
      } else {
        Serial.println("[ERROR] Invalid angle! Please enter a value between 0 and 180.");
      }
    }
    
    printPrompt();
  }
}

void printPrompt() {
  Serial.print("\nEnter target angle (0-180): ");
}