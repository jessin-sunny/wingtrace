import librosa
import numpy as np
import matplotlib.pyplot as plt

audio, sr = librosa.load(r"C:\My\RIT\S8\Project\Dataset\Audio\Pest - New\Nezara_viridula\202262-15-28_Nezara_viridula_000002_s25_ch0.wav", sr=16000)

plt.figure()
D = librosa.amplitude_to_db(np.abs(librosa.stft(audio)), ref=np.max)
librosa.display.specshow(D, sr=sr, x_axis='time', y_axis='hz')
plt.colorbar()
plt.title("Original Spectrogram")
plt.show()