import torch
import torch.nn as nn
from torchvision import models
import cv2
import albumentations as A
from albumentations.pytorch import ToTensorV2


# -----------------------------
# Class Names
# -----------------------------

class_names = [
    "Cicadellidae",
    "Lycorma delicatula",
    "Miridae",
    "aphids",
    "blister beetle",
    "corn borer",
    "whitefly"
]


# -----------------------------
# Image Transform
# -----------------------------

transform = A.Compose([
    A.SmallestMaxSize(max_size=256),
    A.CenterCrop(height=224, width=224),
    A.Normalize(
        mean=(0.485,0.456,0.406),
        std=(0.229,0.224,0.225)
    ),
    ToTensorV2()
])


# -----------------------------
# Device
# -----------------------------

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print("Using device:", device)


# -----------------------------
# Load Model
# -----------------------------

model = models.resnet50(weights=None)

num_classes = 7
model.fc = nn.Linear(model.fc.in_features, num_classes)

model.load_state_dict(
    torch.load(
        r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\pest_resnet50_finetuned.pth"
    )
)

model = model.to(device)
model.eval()


# -----------------------------
# Inference Function
# -----------------------------

def predict_image(image_path):

    image = cv2.imread(image_path)

    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    image = transform(image=image)["image"]

    image = image.unsqueeze(0).to(device)


    with torch.no_grad():

        outputs = model(image)

        # Convert logits to probabilities
        probabilities = torch.nn.functional.softmax(outputs, dim=1)

        confidence, predicted = torch.max(probabilities, 1)


    predicted_class = class_names[predicted.item()]
    confidence_percent = confidence.item() * 100

    return predicted_class, confidence_percent


# -----------------------------
# Test Image
# -----------------------------

image_path = r"C:\My\RIT\S8\Project\Dataset\Image\Pest Unseen\Whitefly\Whitefly-2.webp"

prediction, confidence = predict_image(image_path)

print("\nPredicted Pest Species:", prediction)
print("Confidence: {:.2f}%".format(confidence))