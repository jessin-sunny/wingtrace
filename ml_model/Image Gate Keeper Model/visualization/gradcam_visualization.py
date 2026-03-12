import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import cv2
import numpy as np
from PIL import Image
from torchvision import transforms

from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.image import show_cam_on_image

from models.resnet18_image_gatekeeper import get_resnet18
# from models.efficientnet_image_gatekeeper import get_efficientnet

from config import CLASSES, MODEL_SAVE_PATH


device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# -------------------------------------------------
# Image Transform
# -------------------------------------------------

transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485,0.456,0.406],
        std=[0.229,0.224,0.225]
    )
])


# -------------------------------------------------
# Load Image
# -------------------------------------------------

image_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen\inland-floodwater-mosquito-8840742_640.jpg"

img = Image.open(image_path).convert("RGB")
img = img.resize((224,224))

rgb_img = np.array(img) / 255.0

input_tensor = transform(Image.fromarray((rgb_img*255).astype(np.uint8))).unsqueeze(0).to(device)


# -------------------------------------------------
# Load Model
# -------------------------------------------------

model = get_resnet18().to(device)
# model = get_efficientnet().to(device)

model.load_state_dict(torch.load(MODEL_SAVE_PATH, map_location=device))
model.eval()


# -------------------------------------------------
# Target Layer
# -------------------------------------------------

# ResNet18
target_layers = [model.layer4[-1]]

# EfficientNet
# target_layers = [model.features[-1]]


# -------------------------------------------------
# GradCAM
# -------------------------------------------------

cam = GradCAM(
    model=model,
    target_layers=target_layers
)

grayscale_cam = cam(
    input_tensor=input_tensor,
    targets=None
)[0]


# -------------------------------------------------
# Overlay Heatmap
# -------------------------------------------------

visualization = show_cam_on_image(
    rgb_img,
    grayscale_cam,
    use_rgb=True
)

cv2.imwrite("gradcam_result.jpg", visualization)

print("Grad-CAM saved as gradcam_result.jpg")