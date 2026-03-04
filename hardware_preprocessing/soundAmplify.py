import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt
import sounddevice as sd
from scipy.signal import butter, filtfilt

# ==============================
# SETTINGS
# ==============================
file_path = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest - New\Myzus_persicae\2022224-14-57_Myzus_persicae_000001_s16_ch0.wav"

# ==============================
# LOAD AUDIO
# ==============================
audio, sr = librosa.load(file_path, sr=16000, mono=True)

# ==============================
# BANDPASS (Focus on insect band)
# ==============================
def bandpass_filter(data, sr, lowcut=200, highcut=3000, order=4):
    nyq = 0.5 * sr
    low = lowcut / nyq
    high = highcut / nyq
    b, a = butter(order, [low, high], btype='band')
    return filtfilt(b, a, data)

audio_filtered = bandpass_filter(audio, sr)

# ==============================
# NORMALIZE FOR LISTENING
# ==============================
audio_play = audio_filtered / (np.max(np.abs(audio_filtered)) + 1e-8)
audio_play *= 0.95

print("Playing filtered + normalized audio...")
sd.play(audio_play, sr)
sd.wait()

# ==============================
# SPECTROGRAM
# ==============================
plt.figure(figsize=(10, 6))
D = librosa.amplitude_to_db(np.abs(librosa.stft(audio_filtered, n_fft=1024, hop_length=256)), ref=np.max)
librosa.display.specshow(D, sr=sr, hop_length=256, x_axis='time', y_axis='hz')
plt.ylim(0, 3000)   # zoom into important insect band
plt.colorbar(format='%+2.0f dB')
plt.title("Zoomed Spectrogram (0–3000 Hz)")
plt.tight_layout()
plt.show()

# ==============================
# AVERAGE FREQUENCY SPECTRUM
# ==============================
fft = np.fft.rfft(audio_filtered)
freqs = np.fft.rfftfreq(len(audio_filtered), 1/sr)

plt.figure(figsize=(10, 4))
plt.plot(freqs, 20*np.log10(np.abs(fft)+1e-10))
plt.xlim(0, 3000)
plt.xlabel("Frequency (Hz)")
plt.ylabel("Magnitude (dB)")
plt.title("Average Frequency Spectrum (0–3000 Hz)")
plt.grid()
plt.show()