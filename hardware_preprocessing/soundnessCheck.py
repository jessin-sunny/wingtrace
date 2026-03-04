import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt

file_path = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest - New\Myzus_persicae\2022224-14-57_Myzus_persicae_000001_s16_ch0.wav"

audio, sr = librosa.load(file_path, sr=16000, mono=True)

# ======================
# 1️⃣ RMS CHECK
# ======================
rms = np.sqrt(np.mean(audio**2))
rms_db = 20 * np.log10(rms + 1e-10)

# ======================
# 2️⃣ SPECTRAL FLATNESS
# ======================
flatness = np.mean(librosa.feature.spectral_flatness(y=audio))

# ======================
# 3️⃣ DOMINANT PEAK IN INSECT BAND
# ======================
fft = np.fft.rfft(audio)
freqs = np.fft.rfftfreq(len(audio), 1/sr)
magnitude = np.abs(fft)

# Focus only on insect band
band_mask = (freqs >= 300) & (freqs <= 1200)

band_magnitude = magnitude[band_mask]

peak = np.max(band_magnitude)
mean_band = np.mean(band_magnitude)

band_ratio = peak / (mean_band + 1e-10)

print("RMS dB:", rms_db)
print("Spectral Flatness:", flatness)
print("Band Peak Ratio:", band_ratio)

# ======================
# STRICT DECISION
# ======================
if rms_db > -50 and flatness < 0.25 and band_ratio > 8:
    print("✅ STRONG TONAL INSECT SIGNAL")
else:
    print("❌ Noise / Weak / Not suitable")

# ======================
# Spectrogram
# ======================
plt.figure(figsize=(8,5))
D = librosa.amplitude_to_db(np.abs(librosa.stft(audio)), ref=np.max)
librosa.display.specshow(D, sr=sr, x_axis='time', y_axis='hz')
plt.ylim(0, 2000)
plt.colorbar(format='%+2.0f dB')
plt.title("Spectrogram (0–2000 Hz)")
plt.show()