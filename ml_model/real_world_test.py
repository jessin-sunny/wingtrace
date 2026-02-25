import torch
import torch.nn as nn
from torchvision import models
import librosa
import numpy as np
from collections import Counter

# ======================
# CONFIG
# ======================
MODEL_PATH = "C:\My\RIT\S8\Project\Model\pest_classifier_mobilenetv2.pth"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

SR = 22050
WINDOW_SIZE = 2   # seconds
STRIDE = 1        # seconds

# ======================
# LOAD MODEL
# ======================
checkpoint = torch.load(MODEL_PATH, map_location=DEVICE)
class_names = checkpoint['class_names']

model = models.mobilenet_v2(pretrained=False)
model.classifier[1] = nn.Linear(model.last_channel, 4)
model.load_state_dict(checkpoint['model_state_dict'])
model = model.to(DEVICE)
model.eval()

print("Model loaded.")

# ======================
# PREDICT FUNCTION
# ======================
def predict_file(file_path):

    audio, sr = librosa.load(file_path, sr=SR, mono=True)

    window_samples = int(WINDOW_SIZE * SR)
    stride_samples = int(STRIDE * SR)

    predictions = []
    confidences = []

    for start in range(0, len(audio), stride_samples):
        end = start + window_samples
        segment = audio[start:end]

        if len(segment) < window_samples:
            pad_length = window_samples - len(segment)
            segment = np.pad(segment, (0, pad_length), mode='constant')

        # Create mel spectrogram
        mel = librosa.feature.melspectrogram(
            y=segment,
            sr=SR,
            n_mels=128,
            hop_length=512
        )

        mel_db = librosa.power_to_db(mel, ref=np.max)
        mel_db = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min())

        tensor = torch.tensor(mel_db, dtype=torch.float32)
        tensor = tensor.unsqueeze(0)
        tensor = tensor.repeat(3, 1, 1)
        tensor = tensor.unsqueeze(0)
        tensor = tensor.to(DEVICE)

        with torch.no_grad():
            outputs = model(tensor)
            probs = torch.softmax(outputs, dim=1)
            confidence, predicted = torch.max(probs, 1)

        predictions.append(predicted.item())
        confidences.append(confidence.item())

        if end >= len(audio):
            break

    # Majority Voting
    final_prediction = Counter(predictions).most_common(1)[0][0]
    avg_confidence = np.mean(confidences)

    return class_names[final_prediction], avg_confidence

# ======================
# TEST
# ======================
file_path = r"C:\My\RIT\S8\Project\Audio Recordings\Caterpillar\WT12345678_1771933469.wav"

predicted_class, confidence = predict_file(file_path)

print("\nFinal Prediction:", predicted_class)
print("Average Confidence:", round(confidence, 3))