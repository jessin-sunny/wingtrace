import numpy as np
import librosa
import matplotlib.pyplot as plt

# =====================================
# USER INPUT
# =====================================
file_path = r"C:\Users\jessi\Downloads\WT12345678_1772460937.wav"  # change this

# =====================================
# LOAD AUDIO
# =====================================
audio, sr = librosa.load(file_path, sr=None)

print(f"Sample Rate: {sr}")
print(f"Duration: {len(audio)/sr:.2f} seconds")

# =====================================
# 1️⃣ RMS NOISE LEVEL
# =====================================
rms = np.sqrt(np.mean(audio**2))
rms_db = 20 * np.log10(rms + 1e-10)   # avoid log(0)

print("\n===== NOISE FLOOR =====")
print(f"RMS Value: {rms}")
print(f"Noise Level (dBFS): {rms_db:.2f} dB")

# =====================================
# 2️⃣ PEAK NOISE LEVEL
# =====================================
peak = np.max(np.abs(audio))
peak_db = 20 * np.log10(peak + 1e-10)

print("\n===== PEAK NOISE =====")
print(f"Peak Amplitude: {peak}")
print(f"Peak Level (dBFS): {peak_db:.2f} dB")
print("Mean (DC offset):", np.mean(audio))

# =====================================
# 3️⃣ FFT ANALYSIS (FREQUENCY NOISE)
# =====================================
fft = np.fft.rfft(audio)
fft_magnitude = np.abs(fft)

freqs = np.fft.rfftfreq(len(audio), 1/sr)

plt.figure()
plt.plot(freqs, 20*np.log10(fft_magnitude + 1e-10))
plt.xlabel("Frequency (Hz)")
plt.ylabel("Magnitude (dB)")
plt.title("Noise Spectrum")
plt.xlim(0, sr//2)
plt.show()