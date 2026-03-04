import os
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report

# =========================
# DATASET PATH
# =========================

dataset_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen 3"

# =========================
# DEVICE
# =========================

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", device)

# =========================
# LOAD MODEL
# =========================

model = models.resnet50(weights=None)

num_features = model.fc.in_features
model.fc = nn.Linear(num_features, 3)

model.load_state_dict(
    torch.load(
        r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\mosquito_resnet50_finetuned.pth",
        map_location=device
    )
)

model = model.to(device)
model.eval()

# =========================
# TRANSFORM
# =========================

transform = transforms.Compose([
    transforms.Resize((256,256)),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485,0.456,0.406],
        std=[0.229,0.224,0.225]
    )
])

# =========================
# CLASS MAPPING
# =========================

class_map = {
    "AEDES": 0,
    "ANOPHELES": 1,
    "CULEX": 2
}

all_preds = []
all_labels = []

# =========================
# LOOP THROUGH DATASET
# =========================

for folder in os.listdir(dataset_path):

    folder_path = os.path.join(dataset_path, folder)

    if folder not in class_map:
        continue

    label = class_map[folder]

    print("Processing:", folder)

    for img_name in os.listdir(folder_path):

        img_path = os.path.join(folder_path, img_name)

        try:
            img = Image.open(img_path).convert("RGB")
            img = transform(img).unsqueeze(0).to(device)

            with torch.no_grad():
                output = model(img)

                probs = torch.softmax(output, dim=1)
                pred = torch.argmax(probs).item()

            all_preds.append(pred)
            all_labels.append(label)

        except:
            continue

# =========================
# METRICS
# =========================

accuracy = np.mean(np.array(all_preds) == np.array(all_labels)) * 100

print("\nAccuracy:", accuracy)

cm = confusion_matrix(all_labels, all_preds)

print("\nConfusion Matrix")
print(cm)

print("\nClassification Report")

print(classification_report(
    all_labels,
    all_preds,
    target_names=["Aedes", "Anopheles", "Culex"]
))