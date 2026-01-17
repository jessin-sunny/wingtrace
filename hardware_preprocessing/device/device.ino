#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>   // for https [security]
#include "DHT.h"
#include <driver/i2s.h>
#include <ArduinoJson.h>

#define DHTPIN  27        // your DHT11 pin
#define DHTTYPE DHT11

#define I2S_SCK  14
#define I2S_WS   25
#define I2S_SD   34

#define SAMPLE_RATE 16000
#define BUFFER_LEN  256   // samples

DHT dht(DHTPIN, DHTTYPE);
WiFiClientSecure secureClient;

// ------------------
// CONSTANTS
// ------------------
const char* DEVICE_ID   = "WT12345678";
const char* SERVER_BASE = "https://wingtrace-production.up.railway.app";
// weather timer variables
unsigned long lastWeather = 0;
const unsigned long WEATHER_INTERVAL = 60000; // 1 minute


// ------------------
// OBJECTS
// ------------------
WebServer server(80);
Preferences prefs;

// ------------------
// AP CONFIG (SETUP MODE)
// ------------------
const char* ap_ssid = "WingTrace";
const char* ap_password = "jsevapasn";

// ------------------
// WIFI CREDENTIALS & USERID
// ------------------
String ssid = "";
String password = "";
String userid = "";
String setupToken = "";

// ------------------
// TIMERS
// ------------------
unsigned long lastAlive = 0;
unsigned long lastCommandPoll = 0;

const unsigned long ALIVE_INTERVAL   = 300000; // 5 min
const unsigned long COMMAND_INTERVAL = 5000;  // 5 second

int16_t audioBuffer[BUFFER_LEN];
bool isRecording = false;

// audio part
void initI2S() {
  i2s_config_t cfg = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 8,
    .dma_buf_len = BUFFER_LEN,
    .use_apll = false
  };

  i2s_pin_config_t pins = {
    .bck_io_num = I2S_SCK,
    .ws_io_num  = I2S_WS,
    .data_out_num = -1,
    .data_in_num  = I2S_SD
  };

  i2s_driver_install(I2S_NUM_0, &cfg, 0, NULL);
  i2s_set_pin(I2S_NUM_0, &pins);
  i2s_zero_dma_buffer(I2S_NUM_0);

  Serial.println("I2S initialized");
}

void sendAudioChunk() {
  if (!isRecording || WiFi.status() != WL_CONNECTED) return;

  size_t bytesRead;
  i2s_read(I2S_NUM_0, audioBuffer, sizeof(audioBuffer),
           &bytesRead, portMAX_DELAY);

  HTTPClient http;
  http.begin(secureClient, String(SERVER_BASE) + "/audio");
  http.addHeader("Content-Type", "application/octet-stream");

  int code = http.POST((uint8_t*)audioBuffer, bytesRead);
  if (code < 0) {
    Serial.println("Audio send failed");
  }

  http.end();
}


// ------------------
// SETUP HANDLERS
// ------------------

void handleSetup() {
  if (!server.hasArg("plain")) {
    server.send(400, "text/plain", "No body");
    return;
  }

  String body = server.arg("plain");

  // Expected JSON:
  // { "ssid":"...", "password":"...", "userid":"..." }

  DynamicJsonDocument doc(256);
  deserializeJson(doc, body);

  ssid     = doc["ssid"].as<String>();
  password = doc["password"].as<String>();
  userid   = doc["userid"].as<String>();
  setupToken = doc["setupToken"].as<String>();


  if (ssid == "" || password == "" || userid == "" || setupToken == "") {
    server.send(400, "text/plain", "Invalid data");
    return;
  }

  prefs.begin("wifi", false);
  prefs.putString("ssid", ssid);
  prefs.putString("pass", password);
  prefs.putString("userid", userid);
  prefs.putString("setupToken", setupToken);
  prefs.end();

  server.send(200, "text/plain", "OK");

  delay(1000);
  ESP.restart();
}


// ------------------
// SETUP MODE
// ------------------
void startSetupMode() {
  Serial.println(">>> SETUP MODE");

  WiFi.softAP(ap_ssid, ap_password);
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/setup", HTTP_POST, handleSetup);
  server.begin();
}

// ------------------
// NORMAL MODE
// ------------------
void startNormalMode() {
  Serial.println(">>> NORMAL MODE");

  prefs.begin("wifi", true);
  ssid = prefs.getString("ssid", "");
  password = prefs.getString("pass", "");
  userid = prefs.getString("userid", "");
  setupToken = prefs.getString("setupToken", "");
  prefs.end();

  WiFi.begin(ssid.c_str(), password.c_str());

  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startAttempt < 15000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi failed → Setup mode");
    startSetupMode();
    
    return;
  }

  Serial.println("\nWiFi connected!");
  Serial.println(WiFi.localIP());
  secureClient.setInsecure();  // accept all certificates
  if (setupToken.length() > 0) {
    HTTPClient http;
    http.begin(secureClient, String(SERVER_BASE) + "/onBoard");
    http.addHeader("Content-Type", "application/json");

    String payload =
      "{\"deviceId\":\"" + String(DEVICE_ID) +
      "\",\"userId\":\"" + userid +
      "\",\"setupToken\":\"" + setupToken + "\"}";

    int code = http.POST(payload);
    Serial.println("Onboard message sent, code: " + String(code));
    http.end();

    // CRITICAL: clear token immediately
    prefs.begin("wifi", false);
    prefs.remove("setupToken");
    prefs.end();
  } else {
    Serial.println("Already onboarded — skipping /onBoard");
  }
  initI2S();
  prefs.remove("setupToken");
  sendAlive();
  lastAlive = millis();
}

// ------------------
// SEND HEARTBEAT
// ------------------
void sendAlive() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("ALIVE message failed to send due to no internet");
    return;
  }

  // Get WiFi signal strength (RSSI in dBm)
  int networkStrength = WiFi.RSSI();   // e.g. -30 (strong) to -90 (weak)

  // Fake battery level for now
  int batteryLevel = 100;

  HTTPClient http;
  http.begin(secureClient, String(SERVER_BASE) + "/alive");
  http.addHeader("Content-Type", "application/json");

  String payload =
    "{"
      "\"deviceId\":\"" + String(DEVICE_ID) + "\","
      "\"status\":\"ALIVE\","
      "\"networkStrength\":" + String(networkStrength) + ","
      "\"batteryLevel\":" + String(batteryLevel) +
    "}";

  int code = http.POST(payload);

  Serial.println("ALIVE sent, code: " + String(code));
  Serial.println("RSSI: " + String(networkStrength) + " dBm");
  Serial.println("Battery: " + String(batteryLevel) + "%");

  http.end();
}


// ------------------
// HANDLE COMMAND
// ------------------
void handleCommand(String command) {
  if (command == "RESET") {
    Serial.println(">>> RESET COMMAND RECEIVED");
    prefs.begin("wifi", false);
    prefs.clear();
    prefs.end();
    delay(1000);
    ESP.restart();
  }

  if (command == "START_AUDIO") {
    Serial.println(">>> START AUDIO");
    isRecording = true;
  }

  if (command == "STOP_AUDIO") {
    if (!isRecording) return;   // safety

    Serial.println(">>> STOP AUDIO");
    isRecording = false;

    // DO NOT call /stop here
  }


}




// ------------------
// POLL SERVER COMMAND
// ------------------
void pollServerCommand() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_BASE) + "/command?deviceId=" + DEVICE_ID;
  http.begin(secureClient, url);
  int code = http.GET();

  if (code == 200) {
    String response = http.getString();
    if (response == "NO_COMMAND") {
      return; // do nothing
    }
    Serial.println("Command response: " + response);

    if (response.indexOf("RESET") >= 0) {
      handleCommand("RESET");
    }
    if (response.indexOf("START_AUDIO") >= 0) {
      handleCommand("START_AUDIO");
    }
    if (response.indexOf("STOP_AUDIO") >= 0) {
      handleCommand("STOP_AUDIO");
    }
  }

  http.end();
}

// weather data sending
void sendWeather() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Weather skipped: WiFi not connected");
    return;
  }


  float humidity = NAN;
  float temperature = NAN;

  // Try up to 3 times
  for (int i = 0; i < 3; i++) {
    humidity = dht.readHumidity();
    temperature = dht.readTemperature();
    if (!isnan(humidity) && !isnan(temperature)) {
      break;
    }
    delay(2000);  // DHT needs time
  }

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Failed to read from DHT sensor after retries");
    return;
  }


  HTTPClient http;
  http.begin(secureClient, String(SERVER_BASE) + "/weather");
  http.addHeader("Content-Type", "application/json");

  String payload = "{";
  payload += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
  payload += "\"temperature\":" + String(temperature, 1) + ",";
  payload += "\"humidity\":" + String(humidity, 1);
  payload += "}";

  int code = http.POST(payload);
  Serial.println("Weather sent, code: " + String(code));

  http.end();
}

// ------------------
// SETUP
// ------------------
void setup() {
  Serial.begin(921600);
  dht.begin();
  delay(2000);

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

  unsigned long now = millis();

  if (now - lastAlive > ALIVE_INTERVAL) {
    lastAlive = now;
    sendAlive();
  }

  if (now - lastCommandPoll > COMMAND_INTERVAL) {
    lastCommandPoll = now;
    pollServerCommand();
  }

  if (now - lastWeather > WEATHER_INTERVAL) {
    lastWeather = now;
    sendWeather();
  }

  if (isRecording) {
    sendAudioChunk();   // continuous streaming
  }

}

