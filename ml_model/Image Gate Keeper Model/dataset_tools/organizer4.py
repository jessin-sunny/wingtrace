import os
import shutil
import random
import re
from collections import defaultdict

sources = [
    r"C:\Users\jessi\Downloads\archive\train\Aedes",
    r"C:\Users\jessi\Downloads\archive\test\Aedes"
]

train_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\mosquito"
val_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\mosquito"
test_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\mosquito"

os.makedirs(train_out, exist_ok=True)
os.makedirs(val_out, exist_ok=True)
os.makedirs(test_out, exist_ok=True)

groups = defaultdict(list)

pattern = re.compile(r'^(Aedes\d+)')

# collect files from both train and test
for src in sources:
    for file in os.listdir(src):

        m = pattern.match(file)
        if m:
            key = m.group(1)
            groups[key].append(os.path.join(src, file))

print("Root groups found:", len(groups))

keys = list(groups.keys())
random.shuffle(keys)

total = len(keys)

train_split = int(0.70 * total)
val_split = int(0.15 * total)

train_keys = keys[:train_split]
val_keys = keys[train_split:train_split+val_split]
test_keys = keys[train_split+val_split:]

def copy_group(keys, dest):
    for k in keys:
        for file in groups[k]:
            shutil.copy(file, os.path.join(dest, os.path.basename(file)))

copy_group(train_keys, train_out)
copy_group(val_keys, val_out)
copy_group(test_keys, test_out)

print("Train groups:", len(train_keys))
print("Val groups:", len(val_keys))
print("Test groups:", len(test_keys))