import torch
import torch.nn as nn
import cv2
import numpy as np
import matplotlib.pyplot as plt
from torchvision import models, transforms
from PIL import Image

# =========================
# IMAGE PATH
# =========================

image_path = r"ml_model/Mosquito Image Model/Dataset/test/Aedes/Galaxy-A52s_Ae-aegypti_s01_l2_t1_A0.png"

# =========================
# LOAD MODEL
# =========================

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

model = models.resnet50(weights=None)
num_features = model.fc.in_features
model.fc = nn.Linear(num_features, 3)

model.load_state_dict(torch.load(
    r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\mosquito_resnet50.pth"
))

model = model.to(device)
model.eval()

# =========================
# IMAGE TRANSFORM
# =========================

transform = transforms.Compose([
    transforms.Resize((224,224)),
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
# GRAD-CAM HOOKS
# =========================

gradients = []
activations = []

def backward_hook(module, grad_in, grad_out):
    gradients.append(grad_out[0])

def forward_hook(module, input, output):
    activations.append(output)

target_layer = model.layer4[-1]

target_layer.register_forward_hook(forward_hook)
target_layer.register_backward_hook(backward_hook)

# =========================
# FORWARD PASS
# =========================

output = model(input_tensor)
pred_class = torch.argmax(output)

model.zero_grad()
output[0, pred_class].backward()

# =========================
# COMPUTE GRAD-CAM
# =========================

grads = gradients[0].cpu().data.numpy()[0]
acts = activations[0].cpu().data.numpy()[0]

weights = np.mean(grads, axis=(1,2))

cam = np.zeros(acts.shape[1:], dtype=np.float32)

for i, w in enumerate(weights):
    cam += w * acts[i]

cam = np.maximum(cam, 0)
cam = cam / cam.max()

# =========================
# HEATMAP
# =========================

img_cv = cv2.imread(image_path)
img_cv = cv2.resize(img_cv, (224,224))

heatmap = cv2.resize(cam, (224,224))
heatmap = np.uint8(255 * heatmap)
heatmap = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)

overlay = heatmap * 0.4 + img_cv

# =========================
# SHOW RESULT
# =========================

plt.figure(figsize=(10,5))

plt.subplot(1,2,1)
plt.title("Original Image")
plt.imshow(cv2.cvtColor(img_cv, cv2.COLOR_BGR2RGB))
plt.axis("off")

plt.subplot(1,2,2)
plt.title("Grad-CAM")
plt.imshow(cv2.cvtColor(np.uint8(overlay), cv2.COLOR_BGR2RGB))
plt.axis("off")

plt.show()