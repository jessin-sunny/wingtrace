import os
from PIL import Image
from collections import Counter

train_path = "C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset"

sizes = []

for root, dirs, files in os.walk(train_path):
    for file in files:
        if file.lower().endswith((".jpg", ".jpeg", ".png", ".bmp")):
            img_path = os.path.join(root, file)

            try:
                with Image.open(img_path) as img:
                    sizes.append(img.size)   # (width, height)
            except:
                print("Error reading:", img_path)

size_count = Counter(sizes)

print("\nUnique Image Sizes Found:\n")
for size, count in size_count.items():
    print(f"{size} -> {count} images")

print("\nTotal Images Checked:", len(sizes))