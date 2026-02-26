import torch
import torch.nn as nn
from torchvision import models
import librosa
import numpy as np

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Load checkpoint
checkpoint = torch.load("C:\My\RIT\S8\Project\Model\pest_classifier_mobilenetv2.pth", map_location=DEVICE)
class_names = checkpoint['class_names']

# Rebuild model
model = models.mobilenet_v2(pretrained=False)
model.classifier[1] = nn.Linear(model.last_channel, 4)
model.load_state_dict(checkpoint['model_state_dict'])
model = model.to(DEVICE)
model.eval()

def predict(file_path):
    audio, sr = librosa.load(file_path, sr=22050, mono=True)

    mel = librosa.feature.melspectrogram(
        y=audio,
        sr=22050,
        n_mels=128,
        hop_length=512
    )

    mel_db = librosa.power_to_db(mel, ref=np.max)
    mel_db = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min())

    tensor = torch.tensor(mel_db, dtype=torch.float32).unsqueeze(0)
    tensor = tensor.repeat(3, 1, 1).unsqueeze(0)
    tensor = tensor.to(DEVICE)

    with torch.no_grad():
        outputs = model(tensor)
        _, predicted = torch.max(outputs, 1)

    return class_names[predicted.item()]

# Example usage
file_path = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest 2.0\wood_pests\D9b-cerambycid2-aed.wav"
print("Prediction:", predict(file_path))