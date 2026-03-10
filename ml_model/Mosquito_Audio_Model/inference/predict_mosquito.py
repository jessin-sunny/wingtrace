import sys
import os
import torch
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.resnet_audio import get_mosquito_resnet
from preprocessing.spectrogram import process_audio
from preprocessing.audio_utils import load_audio
from configs.config import SAMPLE_RATE, CLASSES


# -------------------------------------------------
# Device
# -------------------------------------------------

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# -------------------------------------------------
# Model
# -------------------------------------------------

model = get_mosquito_resnet(num_classes=3)

model.load_state_dict(
    torch.load(
        r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\best_mosquito_audio_model.pth",
        map_location=device
    )
)

model = model.to(device)
model.eval()


# -------------------------------------------------
# Window parameters (derived from your dataset)
# -------------------------------------------------

WINDOW_DURATION = 0.608          # seconds
WINDOW_SIZE = int(WINDOW_DURATION * SAMPLE_RATE)

# HumBug-like sliding window
STRIDE = int(WINDOW_SIZE * 0.5)  # 50% overlap


# -------------------------------------------------
# Prediction
# -------------------------------------------------

def predict_audio(file_path):

    signal = load_audio(file_path)

    # pad if shorter than one window
    if len(signal) < WINDOW_SIZE:
        signal = np.pad(signal, (0, WINDOW_SIZE - len(signal)))

    window_probs = []

    for start in range(0, len(signal) - WINDOW_SIZE + 1, STRIDE):

        end = start + WINDOW_SIZE
        window = signal[start:end]

        x = process_audio(window)
        x = x.unsqueeze(0).to(device)

        with torch.no_grad():
            logits = model(x)
            probs = torch.softmax(logits, dim=1)

        window_probs.append(probs.cpu().numpy()[0])

    window_probs = np.array(window_probs)

    # -------------------------------------------------
    # Aggregation (HumBug-style)
    # -------------------------------------------------

    mean_probs = window_probs.mean(axis=0)

    pred_class = np.argmax(mean_probs)
    confidence = mean_probs[pred_class]

    genus = CLASSES[pred_class]

    return genus, confidence, window_probs


# -------------------------------------------------
# Test
# -------------------------------------------------

if __name__ == "__main__":

    audio_file = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus\Anopheles\206814.wav"

    genus, confidence, windows = predict_audio(audio_file)

    print("Prediction:", genus)
    print("Confidence:", confidence)
    print("Window predictions:\n", windows)