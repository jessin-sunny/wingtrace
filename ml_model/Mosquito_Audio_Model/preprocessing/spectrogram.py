# preprocessing/spectrogram.py
import numpy as np
import librosa
import torch

from ml_model.Mosquito_Audio_Model.configs.config import (
    SAMPLE_RATE,
    N_FFT,
    HOP_LENGTH,
    N_MELS,
    WINDOW_FRAMES
)


# -------------------------------------------------
# Generate Log-Mel Spectrogram
# -------------------------------------------------

def generate_log_mel(signal):

    mel = librosa.feature.melspectrogram(
        y=signal,
        sr=SAMPLE_RATE,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS
    )

    mel_db = librosa.power_to_db(mel, ref=np.max)

    return mel_db


# -------------------------------------------------
# Normalize Spectrogram
# -------------------------------------------------

def normalize_spectrogram(mel):

    mean = np.mean(mel)
    std = np.std(mel)

    mel_norm = (mel - mean) / (std + 1e-6)

    return mel_norm


# -------------------------------------------------
# Convert to Tensor
# -------------------------------------------------
def spectrogram_to_tensor(mel):

    # add channel dimension
    mel = np.expand_dims(mel, axis=0)      # 1 × 128 × 19

    # repeat to create 3 channels
    mel = np.repeat(mel, 3, axis=0)        # 3 × 128 × 19

    tensor = torch.tensor(mel, dtype=torch.float32)

    return tensor


# -------------------------------------------------
# Full Pipeline
# -------------------------------------------------

def process_audio(signal):

    mel = generate_log_mel(signal)

    mel = normalize_spectrogram(mel)

    # -------------------------------------------------
    # Force fixed width
    # -------------------------------------------------

    width = mel.shape[1]

    if width < WINDOW_FRAMES:
        pad_width = WINDOW_FRAMES - width
        mel = np.pad(mel, ((0,0),(0,pad_width)), mode='constant')

    elif width > WINDOW_FRAMES:
        mel = mel[:, :WINDOW_FRAMES]

    tensor = spectrogram_to_tensor(mel)

    return tensor