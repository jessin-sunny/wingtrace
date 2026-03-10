# models/resnet_audio.py

import torch.nn as nn
from torchvision import models


def get_mosquito_resnet(num_classes=3):

    # ------------------------------------------------
    # Load pretrained ResNet18
    # ------------------------------------------------

    model = models.resnet18(
        weights=models.ResNet18_Weights.IMAGENET1K_V1
    )

    # ------------------------------------------------
    # Modify first convolution
    # gentler for small spectrogram width
    # ------------------------------------------------

    model.conv1 = nn.Conv2d(
        in_channels=3,
        out_channels=64,
        kernel_size=3,
        stride=1,
        padding=1,
        bias=False
    )

    # ------------------------------------------------
    # Remove aggressive maxpool
    # ------------------------------------------------

    model.maxpool = nn.Identity()

    # ------------------------------------------------
    # Replace classifier
    # ------------------------------------------------

    in_features = model.fc.in_features

    model.fc = nn.Sequential(

        nn.Dropout(p=0.2),

        nn.Linear(in_features, num_classes)

    )

    return model