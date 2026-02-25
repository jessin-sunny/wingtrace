import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, random_split
from torchvision import models
from sklearn.utils.class_weight import compute_class_weight
import numpy as np

from dataset_loader import PestAudioDataset

# ======================
# CONFIG
# ======================
DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest_2.0_Segments"
BATCH_SIZE = 16
EPOCHS = 25
LR = 1e-4
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ======================
# LOAD DATASET
# ======================
dataset = PestAudioDataset(DATASET_PATH)

train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = random_split(dataset, [train_size, val_size])

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE)

# ======================
# CLASS WEIGHTS
# ======================
labels = [dataset.file_list[i][1] for i in range(len(dataset))]
class_weights = compute_class_weight(
    class_weight="balanced",
    classes=np.unique(labels),
    y=labels
)
class_weights = torch.tensor(class_weights, dtype=torch.float).to(DEVICE)

# ======================
# LOAD MODEL
# ======================
model = models.mobilenet_v2(pretrained=True)

# Freeze backbone (important for small dataset)
for param in model.features.parameters():
    param.requires_grad = False

# Replace classifier
model.classifier[1] = nn.Linear(model.last_channel, 4)

model = model.to(DEVICE)

criterion = nn.CrossEntropyLoss(weight=class_weights)
optimizer = optim.Adam(model.parameters(), lr=LR)

# ======================
# TRAINING LOOP
# ======================
for epoch in range(EPOCHS):
    model.train()
    train_loss = 0
    correct = 0
    total = 0

    for inputs, labels in train_loader:
        inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)

        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        train_loss += loss.item()
        _, predicted = torch.max(outputs, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

    train_acc = 100 * correct / total

    # Validation
    model.eval()
    val_correct = 0
    val_total = 0

    with torch.no_grad():
        for inputs, labels in val_loader:
            inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
            outputs = model(inputs)
            _, predicted = torch.max(outputs, 1)
            val_total += labels.size(0)
            val_correct += (predicted == labels).sum().item()

    val_acc = 100 * val_correct / val_total

    print(f"Epoch [{epoch+1}/{EPOCHS}] "
          f"Train Acc: {train_acc:.2f}% "
          f"Val Acc: {val_acc:.2f}%")

print("Training Complete.")
MODEL_SAVE_PATH = "C:\My\RIT\S8\Project\Model\pest_classifier_mobilenetv2.pth"

torch.save({
    'model_state_dict': model.state_dict(),
    'class_names': dataset.classes
}, MODEL_SAVE_PATH)

print(f"Model saved to {MODEL_SAVE_PATH}")