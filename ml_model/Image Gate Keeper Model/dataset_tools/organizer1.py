import os
import random
import shutil

source_dir = r"C:\My\RIT\S8\Project\Dataset\Image\Pest"

train_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\pest"
val_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\pest"
test_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\pest"

os.makedirs(train_dir, exist_ok=True)
os.makedirs(val_dir, exist_ok=True)
os.makedirs(test_dir, exist_ok=True)

for species in os.listdir(source_dir):

    species_path = os.path.join(source_dir, species)

    if not os.path.isdir(species_path):
        continue

    images = [f for f in os.listdir(species_path)
              if f.lower().endswith((".jpg",".jpeg",".png",".bmp"))]

    random.shuffle(images)

    total = len(images)

    train_split = int(0.70 * total)
    val_split = int(0.15 * total)

    train_imgs = images[:train_split]
    val_imgs = images[train_split:train_split + val_split]
    test_imgs = images[train_split + val_split:]

    for img in train_imgs:
        shutil.copy(os.path.join(species_path, img),
                    os.path.join(train_dir, f"{species}_{img}"))

    for img in val_imgs:
        shutil.copy(os.path.join(species_path, img),
                    os.path.join(val_dir, f"{species}_{img}"))

    for img in test_imgs:
        shutil.copy(os.path.join(species_path, img),
                    os.path.join(test_dir, f"{species}_{img}"))

    print(f"{species} -> Train:{len(train_imgs)} Val:{len(val_imgs)} Test:{len(test_imgs)}")

print("Finished splitting dataset")