#include <driver/i2s.h>
#include "DHT.h"

// -------------------
// PIN CONFIGURATION
// -------------------
#define I2S_SCK  14
#define I2S_WS   25
#define I2S_SD   34

#define DHTPIN   13
#define DHTTYPE  DHT11

#define SAMPLE_RATE 16000
#define BUFFER_LEN  256   // samples

int16_t buffer[BUFFER_LEN];

DHT dht(DHTPIN, DHTTYPE);

unsigned long lastDHTRead = 0;

void setup() {
  Serial.begin(921600);
  delay(1000);

  // Init DHT11
  dht.begin();

  // I2S config
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

  // -------- AUDIO --------
  i2s_read(I2S_NUM_0, buffer, sizeof(buffer), &bytes_read, portMAX_DELAY);
  Serial.write((uint8_t*)buffer, bytes_read);
  /*
  // -------- DHT11 (every 2 sec) --------
  if (millis() - lastDHTRead > 2000) {
    float hum = dht.readHumidity();
    float temp = dht.readTemperature();

    if (!isnan(temp) && !isnan(hum)) {
      Serial.print("TEMP:");
      Serial.print(temp);
      Serial.print(",HUM:");
      Serial.println(hum);
    } else {
      Serial.println("DHT11 read error");
    }

    lastDHTRead = millis();
  }
  */
}
