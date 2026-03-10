import torch.nn as nn
from torchvision.models import resnet18, ResNet18_Weights


def get_detector_resnet(num_classes=2):

    model = resnet18(weights=ResNet18_Weights.IMAGENET1K_V1)

    # -------------------------------------------------
    # Adapt first layer for spectrograms
    # -------------------------------------------------

    model.conv1 = nn.Conv2d(
        in_channels=3,
        out_channels=64,
        kernel_size=3,
        stride=1,
        padding=1,
        bias=False
    )

    # -------------------------------------------------
    # Remove aggressive downsampling
    # -------------------------------------------------

    model.maxpool = nn.Identity()

    # -------------------------------------------------
    # Replace classifier
    # -------------------------------------------------

    in_features = model.fc.in_features

    model.fc = nn.Sequential(
        nn.Dropout(0.3),
        nn.Linear(in_features, num_classes)
    )

    return model