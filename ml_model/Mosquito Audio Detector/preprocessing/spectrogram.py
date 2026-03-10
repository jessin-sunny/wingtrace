import numpy as np
import librosa
import torch

SAMPLE_RATE = 8000

N_FFT = 1024
HOP_LENGTH = 256
N_MELS = 128

WINDOW_FRAMES = 19


# -------------------------------------------------
# Generate log-mel spectrogram
# -------------------------------------------------

def generate_log_mel(signal):

    mel = librosa.feature.melspectrogram(
        y=signal,
        sr=SAMPLE_RATE,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS
    )

    mel_db = librosa.power_to_db(mel)

    return mel_db


# -------------------------------------------------
# Convert spectrogram to tensor
# -------------------------------------------------

def spectrogram_to_tensor(mel):

    mel = np.expand_dims(mel, axis=0)   # 1 × mel × time
    mel = np.repeat(mel, 3, axis=0)     # 3 channels for ResNet

    return torch.from_numpy(mel).float()