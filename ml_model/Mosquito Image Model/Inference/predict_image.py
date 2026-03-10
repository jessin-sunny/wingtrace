import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image

# =========================
# IMAGE PATH (EDIT THIS)
# =========================

image_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen\20260308_113429(1).jpeg"

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
# CLASS NAMES
# =========================

class_names = ["Aedes", "Anopheles", "Culex"]

# =========================
# IMAGE TRANSFORM
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
# LOAD IMAGE
# =========================

img = Image.open(image_path).convert("RGB")
input_tensor = transform(img).unsqueeze(0).to(device)

# =========================
# PREDICTION
# =========================

with torch.no_grad():

    output = model(input_tensor)

    probabilities = torch.softmax(output, dim=1)

    confidence, predicted = torch.max(probabilities, 1)

predicted_class = class_names[predicted.item()]

print("\nPrediction:", predicted_class)
print("Confidence:", round(confidence.item()*100, 2), "%")