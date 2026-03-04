import os
import shutil
import random
from collections import defaultdict

input_dir = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito"
output_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Dataset"

train_ratio = 0.7
val_ratio = 0.15
test_ratio = 0.15

def get_base_name(filename):
    name = os.path.splitext(filename)[0]
    parts = name.split("_")
    return "_".join(parts[:-1])

for cls in os.listdir(input_dir):

    cls_path = os.path.join(input_dir, cls)

    if not os.path.isdir(cls_path):
        continue

    print(f"\nProcessing {cls}")

    groups = defaultdict(list)

    for file in os.listdir(cls_path):
        base = get_base_name(file)
        groups[base].append(file)

    base_keys = list(groups.keys())
    random.shuffle(base_keys)

    total = len(base_keys)

    train_end = int(train_ratio * total)
    val_end = train_end + int(val_ratio * total)

    train_keys = base_keys[:train_end]
    val_keys = base_keys[train_end:val_end]
    test_keys = base_keys[val_end:]

    split_map = {
        "train": train_keys,
        "val": val_keys,
        "test": test_keys
    }

    for split in split_map:

        split_cls_path = os.path.join(output_dir, split, cls)
        os.makedirs(split_cls_path, exist_ok=True)

        for key in split_map[split]:
            for file in groups[key]:

                src = os.path.join(cls_path, file)
                dst = os.path.join(split_cls_path, file)

                shutil.copy(src, dst)

print("\nDataset split completed.")