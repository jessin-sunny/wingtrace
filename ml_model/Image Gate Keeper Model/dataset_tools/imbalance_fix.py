import os
import random

base_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset"

splits = ["train", "val", "test"]

target = {
    "train": 15577,
    "val": 3319,
    "test": 3364
}

for split in splits:

    pest_path = os.path.join(base_path, split, "pest")

    images = os.listdir(pest_path)
    random.shuffle(images)

    keep = target[split]

    remove_imgs = images[keep:]

    for img in remove_imgs:
        os.remove(os.path.join(pest_path, img))

    print(split, "kept:", keep, "removed:", len(remove_imgs))