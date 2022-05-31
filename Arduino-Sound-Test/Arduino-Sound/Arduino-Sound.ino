#include <M5StickCPlus.h>

const int BUTTON_A = 37;
bool onBuzzer = true;

void handleInterrupt() {
  onBuzzer = !onBuzzer;
}

void setup() {
  M5.begin();
  pinMode(BUTTON_A, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(BUTTON_A), handleInterrupt, FALLING);
}

void loop() {
  M5.update();
  M5.Beep.update();           // tone関数で鳴らした音が指定時間経過していたら止める

  if(onBuzzer) {
    soundTest();
  }
  delay(5);
}
void soundTest() {
  M5.Beep.tone(3000);
  delay(100);
  M5.Beep.tone(1000);
  delay(100);
  M5.Beep.end();
  onBuzzer = !onBuzzer;
  
}
