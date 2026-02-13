import librosa
import librosa.display
import matplotlib.pyplot as plt
import numpy as np

# -------------------------------
# Load audio (RAW)
# -------------------------------
wav_path = "recordings/music.wav"
y, sr = librosa.load(wav_path, sr=None)

# -------------------------------
# Parameters
# -------------------------------
chunk_duration = 1.0            # seconds
chunk_samples = int(chunk_duration * sr)

n_fft = 2048
hop_length = 512
n_mels = 64

# -------------------------------
# Split into 1s chunks
# -------------------------------
num_chunks = len(y) // chunk_samples

print(f"Total chunks: {num_chunks}")

for i in range(num_chunks):
    start = i * chunk_samples
    end = start + chunk_samples
    y_chunk = y[start:end]

    # -------------------------------
    # Compute Mel spectrogram
    # -------------------------------
    mel_spec = librosa.feature.melspectrogram(
        y=y_chunk,
        sr=sr,
        n_fft=n_fft,
        hop_length=hop_length,
        n_mels=n_mels,
        fmin=0,
        fmax=sr // 2
    )

    # Convert to log scale
    log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)

    # -------------------------------
    # Plot Log-Mel Spectrogram
    # -------------------------------
    plt.figure(figsize=(8, 3))
    librosa.display.specshow(
        log_mel_spec,
        x_axis='time',
        y_axis='mel',
        sr=sr,
        hop_length=hop_length
    )
    plt.colorbar(label='Log-Mel (dB)')
    plt.title(f'Log-Mel Spectrogram | Chunk {i+1} ({i}-{i+1}s)')
    plt.tight_layout()
    plt.show()
