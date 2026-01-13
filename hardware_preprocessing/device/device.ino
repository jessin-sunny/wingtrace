#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include "DHT.h"
#include <driver/i2s.h>

// ------------------
// SENSOR CONFIG
// ------------------
#define DHTPIN  27
#define DHTTYPE DHT11

#define I2S_SCK  14
#define I2S_WS   25
#define I2S_SD   34

#define SAMPLE_RATE 16000
#define BUFFER_LEN  256

DHT dht(DHTPIN, DHTTYPE);

// ------------------
// CONSTANTS
// ------------------
const char* DEVICE_ID   = "WT12012026";
const char* SERVER_BASE = "https://wingtrace-production.up.railway.app";

// pairing
#define PAIR_TIMEOUT_MS 300000   // 5 minutes
#define PAIR_POLL_MS    8000     // 8 seconds

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
// WIFI STORAGE
// ------------------
String temp_ssid = "";
String temp_pass = "";

String ssid = "";
String password = "";

// ------------------
// STATE FLAGS
// ------------------
bool inSetupMode = false;
bool wifiTestPending = false;

// ------------------
// TIMERS
// ------------------
unsigned long lastAlive = 0;
unsigned long lastCommandPoll = 0;
unsigned long lastWeather = 0;

const unsigned long ALIVE_INTERVAL   = 300000;
const unsigned long COMMAND_INTERVAL = 1000;
const unsigned long WEATHER_INTERVAL = 60000;

// ------------------
// AUDIO
// ------------------
int16_t audioBuffer[BUFFER_LEN];
bool isRecording = false;

// ------------------
// HTML SETUP PAGE
// ------------------
const char* setup_page = R"rawliteral(
<!DOCTYPE html>
<html>
<head><title>WingTrace Setup</title></head>
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
// AUDIO INIT
// ------------------
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
}

// ------------------
// AUDIO STREAM
// ------------------
void sendAudioChunk() {
  if (!isRecording || WiFi.status() != WL_CONNECTED) return;

  size_t bytesRead;
  i2s_read(I2S_NUM_0, audioBuffer, sizeof(audioBuffer),
           &bytesRead, portMAX_DELAY);

  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/audio");
  http.addHeader("Content-Type", "application/octet-stream");
  http.POST((uint8_t*)audioBuffer, bytesRead);
  http.end();
}

// ------------------
// SETUP HANDLERS
// ------------------
void handleRoot() {
  server.send(200, "text/html", setup_page);
}

void handleSave() {
  temp_ssid = server.arg("ssid");
  temp_pass = server.arg("password");

  Serial.println("WiFi credentials received (no validation)");

  String response = "{";
  response += "\"status\":\"ok\",";
  response += "\"device_id\":\"" + String(DEVICE_ID) + "\"";
  response += "}";

  server.send(200, "application/json", response);

  // WiFi connection happens later (outside HTTP)
  wifiTestPending = true;
}

// ------------------
// WIFI CONNECT + PAIRING (NO WIFI VALIDATION)
// ------------------
void connectWiFiAndWaitForPairing() {
  Serial.println("Switching AP → STA (no WiFi validation)");

  server.stop();
  delay(200);

  WiFi.softAPdisconnect(true);
  delay(200);

  WiFi.mode(WIFI_OFF);
  delay(300);

  WiFi.mode(WIFI_STA);
  WiFi.begin(temp_ssid.c_str(), temp_pass.c_str());

  Serial.println("Waiting for pairing (app handles WiFi failure)");

  unsigned long pairStart = millis();
  while (millis() - pairStart < PAIR_TIMEOUT_MS) {
    if (isPairedOnServer()) {
      saveWiFiAndReboot();
      return;
    }
    delay(PAIR_POLL_MS);
  }

  Serial.println("Pairing timeout → restart setup");
  restartSetup();
}

bool isPairedOnServer() {
  HTTPClient http;
  http.begin(String(SERVER_BASE) +
             "/pairing/status?device_id=" + DEVICE_ID);
  int code = http.GET();

  if (code == 200) {
    String body = http.getString();
    http.end();
    return body.indexOf("paired") >= 0;
  }

  http.end();
  return false;
}

void saveWiFiAndReboot() {
  prefs.begin("wifi", false);
  prefs.putString("ssid", temp_ssid);
  prefs.putString("pass", temp_pass);
  prefs.end();

  delay(1000);
  ESP.restart();
}

void restartSetup() {
  WiFi.disconnect(true);
  temp_ssid = "";
  temp_pass = "";
  delay(1000);
  startSetupMode();
}

// ------------------
// SETUP MODE
// ------------------
void startSetupMode() {
  Serial.println(">>> SETUP MODE");

  inSetupMode = true;

  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);

  server.on("/", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.begin();
}

// ------------------
// NORMAL MODE
// ------------------
void startNormalMode() {
  inSetupMode = false;

  prefs.begin("wifi", true);
  ssid = prefs.getString("ssid", "");
  password = prefs.getString("pass", "");
  prefs.end();

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), password.c_str());

  initI2S();
}

// ------------------
// HEARTBEAT
// ------------------
void sendAlive() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/alive");
  http.addHeader("Content-Type", "application/json");

  String payload =
    "{\"deviceId\":\"" + String(DEVICE_ID) + "\",\"status\":\"ALIVE\"}";
  http.POST(payload);
  http.end();
}

// ------------------
// COMMAND POLL
// ------------------
void pollServerCommand() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/command?deviceId=" + DEVICE_ID);
  int code = http.GET();

  if (code == 200) {
    String cmd = http.getString();
    if (cmd.indexOf("RESET") >= 0) {
      prefs.begin("wifi", false);
      prefs.clear();
      prefs.end();
      ESP.restart();
    }
    if (cmd.indexOf("START_AUDIO") >= 0) isRecording = true;
    if (cmd.indexOf("STOP_AUDIO") >= 0) isRecording = false;
  }

  http.end();
}

// ------------------
// WEATHER
// ------------------
void sendWeather() {
  if (WiFi.status() != WL_CONNECTED) return;

  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (isnan(h) || isnan(t)) return;

  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/weather");
  http.addHeader("Content-Type", "application/json");

  String payload = "{";
  payload += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
  payload += "\"temperature\":" + String(t, 1) + ",";
  payload += "\"humidity\":" + String(h, 1);
  payload += "}";

  http.POST(payload);
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

  if (hasSSID) startNormalMode();
  else startSetupMode();
}

// ------------------
// LOOP
// ------------------
void loop() {
  if (inSetupMode) {
    server.handleClient();
  }

  if (wifiTestPending) {
    wifiTestPending = false;
    connectWiFiAndWaitForPairing();
    return;
  }

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
    sendAudioChunk();
  }
}
