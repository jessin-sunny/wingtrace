#include <driver/i2s.h>

// -------------------
// PIN CONFIGURATION
// -------------------
#define I2S_SCK  14
#define I2S_WS   25
#define I2S_SD   34

#define GREEN_LED 13
#define RED_LED   27

#define SAMPLE_RATE 16000
#define BUFFER_LEN  256   // samples

int16_t buffer[BUFFER_LEN];

unsigned long lastBlink = 0;
bool ledState = false;

void setup() {
  Serial.begin(921600);   // IMPORTANT
  delay(1000);

  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);

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

void loop() {
  size_t bytes_read;

  i2s_read(I2S_NUM_0, buffer, sizeof(buffer), &bytes_read, portMAX_DELAY);

  

  // Send RAW PCM
  Serial.write((uint8_t*)buffer, bytes_read);

  // GREEN LED heartbeat
  if (millis() - lastBlink > 1000) {
    ledState = !ledState;
    digitalWrite(GREEN_LED, ledState);
    lastBlink = millis();
  }

  // RED LED for loud sound
  if (abs(buffer[0]) > 2000) {
    digitalWrite(RED_LED, HIGH);
  } else {
    digitalWrite(RED_LED, LOW);
  }
}
