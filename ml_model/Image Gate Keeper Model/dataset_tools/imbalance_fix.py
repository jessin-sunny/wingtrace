import os
import random

base_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset"

splits = ["train", "val", "test"]

target = {
    "train": 4181,
    "val": 875,
    "test": 932
}

for split in splits:

    pest_path = os.path.join(base_path, split, "neither")

    images = os.listdir(pest_path)
    random.shuffle(images)

    keep = target[split]

    remove_imgs = images[keep:]

    for img in remove_imgs:
        os.remove(os.path.join(pest_path, img))

    print(split, "kept:", keep, "removed:", len(remove_imgs))