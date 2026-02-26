import torch
from torch.utils.data import DataLoader
from dataset_loader import PestAudioDataset

DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest_2.0_Segments"

dataset = PestAudioDataset(DATASET_PATH)
loader = DataLoader(dataset, batch_size=8, shuffle=True)

print("Number of samples:", len(dataset))
print("Classes:", dataset.classes)

for batch_data, batch_labels in loader:
    print("Batch shape:", batch_data.shape)
    print("Batch labels:", batch_labels)
    break