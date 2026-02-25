import os
import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt

# ==========================
# CONFIGURATION
# ==========================
AUDIO_FOLDER = "recordings\Rain"
N_MELS = 128
FMAX = 8000   # adjust based on mosquito frequency range
DURATION = 5  # seconds (optional trimming)

# ==========================
# PROCESS FUNCTION
# ==========================
def process_audio(file_path):
    print(f"\nProcessing: {file_path}")
    
    # Load audio
    y, sr = librosa.load(file_path, duration=DURATION)
    
    # -------------------------
    # 1️⃣ Loudness (RMS + dB)
    # -------------------------
    rms = np.sqrt(np.mean(y**2))
    db = librosa.amplitude_to_db(np.array([rms]), ref=1.0)[0]
    
    print(f"Sample Rate: {sr} Hz")
    print(f"Duration: {len(y)/sr:.2f} sec")
    print(f"RMS Loudness: {rms:.6f}")
    print(f"Loudness (dB): {db:.2f} dB")
    
    # -------------------------
    # 2️⃣ Frequency Spectrum
    # -------------------------
    fft = np.abs(np.fft.fft(y))
    freqs = np.fft.fftfreq(len(fft), 1/sr)
    
    positive_freqs = freqs[:len(freqs)//2]
    positive_fft = fft[:len(fft)//2]
    
    dominant_freq = positive_freqs[np.argmax(positive_fft)]
    print(f"Dominant Frequency: {dominant_freq:.2f} Hz")
    print(f"Frequency Range: 0 - {sr/2:.2f} Hz")
    
    # Plot Frequency Spectrum
    plt.figure(figsize=(10,4))
    plt.plot(positive_freqs, positive_fft)
    plt.title("Frequency Spectrum")
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude")
    plt.xlim(0, 2000)  # adjust if needed
    plt.tight_layout()
    plt.show()
    
    # -------------------------
    # 3️⃣ Log-Mel Spectrogram
    # -------------------------
    mel_spec = librosa.feature.melspectrogram(
        y=y,
        sr=sr,
        n_mels=N_MELS,
        fmax=FMAX
    )
    
    log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)
    
    plt.figure(figsize=(10,4))
    librosa.display.specshow(
        log_mel_spec,
        sr=sr,
        x_axis='time',
        y_axis='mel',
        fmax=FMAX
    )
    plt.colorbar(format='%+2.0f dB')
    plt.title("Log-Mel Spectrogram")
    plt.tight_layout()
    plt.show()


# ==========================
# LOOP THROUGH FOLDER
# ==========================
for file in os.listdir(AUDIO_FOLDER):
    if file.endswith(".wav"):
        process_audio(os.path.join(AUDIO_FOLDER, file))