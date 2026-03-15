import sys
import os

# allow imports from project root
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
from PIL import Image
from torchvision import transforms

from models.resnet50_image_gatekeeper import get_resnet50
from config import MODEL_SAVE_PATH, CLASSES


def main():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Running on:", device)

    # Load model
    model = get_resnet50()

    model.load_state_dict(
        torch.load(MODEL_SAVE_PATH, map_location=device)
    )

    model.to(device)
    model.eval()

    # Validation transform for resnet
    # transform = transforms.Compose([
    #     transforms.Resize(256),
    #     transforms.CenterCrop(224),
    #     transforms.ToTensor(),
    #     transforms.Normalize(
    #         mean=[0.485,0.456,0.406],
    #         std=[0.229,0.224,0.225]
    #     )
    # ])

    # aggresive transform -simple for predict
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])

    # transform = transforms.Compose([
    #     transforms.Resize((224, 224)),

    #     transforms.ToTensor(),

    #     transforms.Normalize(
    #         mean=[0.485,0.456,0.406],
    #         std=[0.229,0.224,0.225]
    #     )
    # ])

    # Direct image path
    image_path = r"C:\Users\jessi\Downloads\WhatsApp Image 2026-03-13 at 5.28.25 PM.jpeg"

    image = Image.open(image_path).convert("RGB")

    image = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():

        outputs = model(image)

        probs = torch.softmax(outputs, dim=1)

        confidence, predicted = torch.max(probs, 1)

    class_name = CLASSES[predicted.item()]

    print("\nPrediction:", class_name)
    print("Confidence:", confidence.item())
    for i, class_name in enumerate(CLASSES):
        percentage = probs[0][i].item() * 100
        print(f"{class_name}: {percentage:.2f}%")

if __name__ == "__main__":
    main()