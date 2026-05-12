import os
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

# =============================
# DATASET PATH
# =============================

dataset_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen 2"

# =============================
# DEVICE
# =============================

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", device)

# =============================
# LOAD MODEL
# =============================

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

# =============================
# CLASS NAMES
# =============================

class_names = ["Aedes", "Anopheles", "Culex"]

# =============================
# TRANSFORM (MATCH TRAINING)
# =============================

transform = transforms.Compose([
    transforms.Resize((256,256)),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485,0.456,0.406],
        std=[0.229,0.224,0.225]
    )
])

# =============================
# LABEL MAPPING
# =============================

def get_label_from_folder(folder_name):

    folder_name = folder_name.lower()

    if "aedes" in folder_name:
        return "Aedes"

    if "culex" in folder_name:
        return "Culex"

    return None


# =============================
# EVALUATION
# =============================

y_true = []
y_pred = []

for folder in os.listdir(dataset_path):

    if folder == "data_splitting":
        continue

    label = get_label_from_folder(folder)

    if label is None:
        continue

    print("Processing:", folder)

    folder_path = os.path.join(dataset_path, folder)

    for img_name in os.listdir(folder_path):

        img_path = os.path.join(folder_path, img_name)

        try:
            img = Image.open(img_path).convert("RGB")
            img = transform(img).unsqueeze(0).to(device)

            with torch.no_grad():
                output = model(img)
                pred = torch.argmax(output, 1).item()

            predicted_label = class_names[pred]

            if predicted_label not in ["Aedes","Culex"]:
                continue

            y_true.append(label)
            y_pred.append(predicted_label)

        except:
            continue


# =============================
# RESULTS
# =============================

labels = ["Aedes","Culex"]

print("\nAccuracy:", accuracy_score(y_true,y_pred)*100)

print("\nConfusion Matrix")
print(confusion_matrix(y_true,y_pred,labels=labels))

print("\nClassification Report")
print(classification_report(y_true,y_pred,target_names=labels))