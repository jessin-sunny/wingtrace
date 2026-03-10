import os
import random
import shutil

SOURCE_DIR = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus"

TRAIN_DIR = os.path.join(SOURCE_DIR, "train")
TEST_DIR = os.path.join(SOURCE_DIR, "test")

CLASSES = ["Aedes", "Anopheles", "Culex"]

TRAIN_SAMPLES_PER_CLASS = 150

random.seed(42)


def create_dirs():

    for split in ["train", "test"]:
        for c in CLASSES:

            path = os.path.join(SOURCE_DIR, split, c)

            os.makedirs(path, exist_ok=True)


def split_dataset():

    for c in CLASSES:

        class_path = os.path.join(SOURCE_DIR, c)

        files = [f for f in os.listdir(class_path) if f.endswith(".wav")]

        random.shuffle(files)

        train_files = files[:TRAIN_SAMPLES_PER_CLASS]

        test_files = files[TRAIN_SAMPLES_PER_CLASS:]

        print(f"{c}: Train={len(train_files)}, Test={len(test_files)}")

        for f in train_files:

            src = os.path.join(class_path, f)

            dst = os.path.join(TRAIN_DIR, c, f)

            shutil.copy(src, dst)

        for f in test_files:

            src = os.path.join(class_path, f)

            dst = os.path.join(TEST_DIR, c, f)

            shutil.copy(src, dst)


if __name__ == "__main__":

    create_dirs()

    split_dataset()

    print("Dataset split completed.")