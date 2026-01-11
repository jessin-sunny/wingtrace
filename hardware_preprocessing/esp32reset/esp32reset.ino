#include <Preferences.h>

Preferences prefs;

void setup() {
  Serial.begin(115200);

  // Erase Wi-Fi namespace completely
  prefs.begin("wifi", false);
  prefs.clear();   // removes all saved keys in "wifi"
  prefs.end();

  Serial.println("All stored credentials cleared. Starting fresh...");


}

void loop() {

}

