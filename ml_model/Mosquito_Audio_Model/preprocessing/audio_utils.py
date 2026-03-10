# preprocessing/audio_utils.py

import numpy as np
import librosa
import random

from configs.config import (
    SAMPLE_RATE,
    AUG_NONE,
    AUG_NOISE,
    AUG_GAIN,
    AUG_SHIFT,
    AUG_STRETCH
)


# -------------------------------------------------
# Load audio
# -------------------------------------------------

def load_audio(file_path):
    signal, sr = librosa.load(file_path, sr=SAMPLE_RATE)

    return signal


# -------------------------------------------------
# Add Gaussian Noise
# -------------------------------------------------

def add_noise(signal):

    noise_amp = 0.005 * np.random.uniform() * np.max(signal)

    noise = noise_amp * np.random.normal(size=len(signal))

    return signal + noise


# -------------------------------------------------
# Gain Change
# -------------------------------------------------

def gain_change(signal):

    gain = np.random.uniform(0.8, 1.2)

    return signal * gain


# -------------------------------------------------
# Time Shift
# -------------------------------------------------

def time_shift(signal):

    shift = int(np.random.uniform(-0.1, 0.1) * len(signal))

    return np.roll(signal, shift)


# -------------------------------------------------
# Time Stretch
# -------------------------------------------------

def time_stretch(signal):

    rate = np.random.uniform(0.9, 1.1)

    stretched = librosa.effects.time_stretch(signal, rate=rate)

    return stretched


# -------------------------------------------------
# Augmentation Controller
# -------------------------------------------------

def apply_augmentation(signal):

    r = random.random()

    if r < AUG_NONE:

        return signal

    elif r < AUG_NONE + AUG_NOISE:

        return add_noise(signal)

    elif r < AUG_NONE + AUG_NOISE + AUG_GAIN:

        return gain_change(signal)

    elif r < AUG_NONE + AUG_NOISE + AUG_GAIN + AUG_SHIFT:

        return time_shift(signal)

    else:

        return time_stretch(signal)