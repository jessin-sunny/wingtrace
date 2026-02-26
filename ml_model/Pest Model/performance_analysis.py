import torch
import torch.nn as nn
from torch.utils.data import DataLoader, random_split
from torchvision import models
from sklearn.metrics import confusion_matrix, classification_report
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np

from dataset_loader import PestAudioDataset

# ======================
# CONFIG
# ======================
DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest_2.0_Segments"
MODEL_PATH = "C:\My\RIT\S8\Project\Model\pest_classifier_mobilenetv2.pth"
BATCH_SIZE = 16
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print("Using device:", DEVICE)

# ======================
# LOAD DATASET
# ======================
dataset = PestAudioDataset(DATASET_PATH)

# Same 80/20 split as training
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
_, val_dataset = random_split(dataset, [train_size, val_size])

val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE)

print("Validation samples:", len(val_dataset))
print("Classes:", dataset.classes)

# ======================
# LOAD MODEL
# ======================
checkpoint = torch.load(MODEL_PATH, map_location=DEVICE)

model = models.mobilenet_v2(pretrained=False)
model.classifier[1] = nn.Linear(model.last_channel, 4)

model.load_state_dict(checkpoint['model_state_dict'])
model = model.to(DEVICE)
model.eval()

print("Model loaded successfully.")

# ======================
# EVALUATION
# ======================
all_preds = []
all_labels = []

with torch.no_grad():
    for inputs, labels in val_loader:
        inputs = inputs.to(DEVICE)
        outputs = model(inputs)
        _, predicted = torch.max(outputs, 1)

        all_preds.extend(predicted.cpu().numpy())
        all_labels.extend(labels.numpy())

# ======================
# METRICS
# ======================
cm = confusion_matrix(all_labels, all_preds)

print("\n=== Classification Report ===\n")
print(classification_report(all_labels, all_preds,
                            target_names=dataset.classes))

# ======================
# CONFUSION MATRIX PLOT
# ======================
plt.figure(figsize=(6,5))
sns.heatmap(cm,
            annot=True,
            fmt="d",
            xticklabels=dataset.classes,
            yticklabels=dataset.classes,
            cmap="Blues")

plt.xlabel("Predicted")
plt.ylabel("True")
plt.title("Confusion Matrix")
plt.tight_layout()
plt.show()