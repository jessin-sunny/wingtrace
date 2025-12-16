#include <driver/i2s.h>

// -------------------
// PIN CONFIGURATION
// -------------------
#define I2S_SCK  14
#define I2S_WS   25
#define I2S_SD   34

// LED PINS
#define GREEN_LED 13
#define RED_LED   27

void setup() {
  Serial.begin(115200);
  delay(1000);

  // LED setup
  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);

  // Turn OFF LEDs initially
  digitalWrite(GREEN_LED, LOW);
  digitalWrite(RED_LED, LOW);

  //Serial.println("Starting INMP441 microphone...");

  // I2S configuration
  i2s_config_t cfg = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = 16000,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = 32,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0
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

  Serial.println("Microphone ready!");
}

unsigned long lastBlink = 0;
bool ledState = false;

void loop() {
  // Blink GREEN LED every 1 second
  if (millis() - lastBlink >= 1000) {
    ledState = !ledState;
    digitalWrite(GREEN_LED, ledState);
    lastBlink = millis();
  }

  // Read I2S audio sample
  int32_t sample32 = 0;
  size_t bytes_read = 0;
  i2s_read(I2S_NUM_0, &sample32, sizeof(sample32), &bytes_read, portMAX_DELAY);

  int32_t val = sample32;  // raw

  Serial.println(val);

  // OPTIONAL: Light RED LED if loud sound detected
  if (abs(val) > 50000) {
    digitalWrite(RED_LED, HIGH);
  } else {
    digitalWrite(RED_LED, LOW);
  }
}