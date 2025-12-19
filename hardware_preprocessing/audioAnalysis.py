import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import librosa

# Load your audio
audio = np.load("recording.npy")
sr = 16000  # sample rate
time = np.arange(len(audio)) / sr

# graph Amplitude v/s Time
plt.figure(figsize=(12, 4))
plt.plot(time, audio)
plt.title("Full Waveform")
plt.xlabel("Time (s)")
plt.ylabel("Amplitude")
plt.show()

#spectrogram
# Compute spectrogram
f, t, Sxx = signal.spectrogram(audio, fs=sr, nperseg=512, noverlap=256)

# Plot spectrogram
plt.figure(figsize=(12, 6))
plt.pcolormesh(t, f, 10*np.log10(Sxx), shading='gouraud')  # convert to dB
plt.ylabel('Frequency [Hz]')
plt.xlabel('Time [sec]')
plt.title('Spectrogram')
plt.colorbar(label='Intensity [dB]')
plt.ylim(0, 8000)  # optional, focus on human + mosquito range
plt.show()

#MFCC
mfcc = librosa.feature.mfcc(
    y=audio.astype(np.float32) / 32768.0,  # normalize int16 → float
    sr=sr,
    n_mfcc=13,
    n_fft=1024,
    hop_length=512
)

np.save("recording_mfcc.npy", mfcc)
print("MFCC saved as recording_mfcc.npy")

mfcc_loaded = np.load("recording_mfcc.npy")

print("Loaded MFCC shape:", mfcc_loaded.shape)
print("First MFCC frame:")
print(mfcc_loaded[:, 0])
