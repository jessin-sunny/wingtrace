#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>


// ------------------
// OBJECTS
// ------------------
WebServer server(80);
Preferences prefs;

// ------------------
// AP CONFIG
// ------------------
const char* ap_ssid = "WingTrace_V1";
const char* ap_password = "jsevapasn";

// ------------------
// WIFI CREDENTIALS
// ------------------
String ssid = "";
String password = "";

// ------------------
// SIMPLE HTML PAGE
// ------------------
const char* setup_page = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <title>ESP32 Setup</title>
</head>
<body>
  <h2>WiFi Setup</h2>
  <form action="/save" method="POST">
    SSID:<br>
    <input type="text" name="ssid"><br><br>
    Password:<br>
    <input type="password" name="password"><br><br>
    <input type="submit" value="Save">
  </form>
</body>
</html>
)rawliteral";

// ------------------
// HANDLERS
// ------------------
void handleRoot() {
  server.send(200, "text/html", setup_page);
}

void handleSave() {
  ssid = server.arg("ssid");
  password = server.arg("password");

  Serial.println("Received WiFi credentials:");
  Serial.println("SSID: " + ssid);
  Serial.println("Password: " + password);

  // ---- SAVE TO NVS ----
  prefs.begin("wifi", false);   // namespace "wifi"
  prefs.putString("ssid", ssid);
  prefs.putString("pass", password);
  prefs.end();

  server.send(200, "text/plain", "Credentials saved. Device will reboot and connect to WiFi.");

  delay(3000);
  ESP.restart();
}

// ------------------
// SETUP MODE
// ------------------
void startSetupMode() {
  Serial.println("Starting SETUP MODE");

  WiFi.softAP(ap_ssid, ap_password);
  Serial.print("Setup AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.begin();

  Serial.println("Setup server started");
}

// ------------------
// NORMAL MODE
// ------------------
void startNormalMode() {
  Serial.println("Starting NORMAL MODE");

  prefs.begin("wifi", true);
  ssid = prefs.getString("ssid", "");
  password = prefs.getString("pass", "");
  prefs.end();

  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.begin(ssid.c_str(), password.c_str());

  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startAttempt < 15000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());

    // ----------------------------
    // SEND ALIVE MESSAGE
    // ----------------------------
    HTTPClient http;
    String serverUrl = "http://192.168.18.41:5000/alive"; // replace with your PC IP
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    String payload = "{\"deviceId\":\"WingTraceV1\",\"status\":\"ALIVE\"}";
    int httpResponseCode = http.POST(payload);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println("Server response: " + response);
    } else {
      Serial.println("Error sending ALIVE: " + String(httpResponseCode));
    }

    http.end();
}
else {
    Serial.println("\nWiFi failed. Returning to SETUP MODE");
    startSetupMode();
  }
}

// ------------------
// SETUP
// ------------------
void setup() {
  Serial.begin(921600);

  prefs.begin("wifi", true);
  bool hasSSID = prefs.isKey("ssid");
  prefs.end();

  if (hasSSID) {
    startNormalMode();
  } else {
    startSetupMode();
  }
}

// ------------------
// LOOP
// ------------------
void loop() {
  server.handleClient();
}
