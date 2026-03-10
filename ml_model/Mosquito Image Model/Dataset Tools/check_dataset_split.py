import os

train_mosq = "ml_model/Mosquito Audio Detector/dataset/train/mosquito"
train_noise = "ml_model/Mosquito Audio Detector/dataset/train/noise"

val_mosq = "ml_model/Mosquito Audio Detector/dataset/val/mosquito"
val_noise = "ml_model/Mosquito Audio Detector/dataset/val/noise"


def show_examples(path, name):

    files = sorted(os.listdir(path))

    print(f"\n{name}")
    print("Total files:", len(files))

    for f in files[:10]:
        print(f)


def check_overlap(path1, path2, name1, name2):

    set1 = set(os.listdir(path1))
    set2 = set(os.listdir(path2))

    overlap = set1.intersection(set2)

    print(f"\nOverlap between {name1} and {name2}: {len(overlap)}")

    if overlap:
        print("Example overlaps:")
        for f in list(overlap)[:10]:
            print(f)


show_examples(train_mosq, "Train Mosquito")
show_examples(train_noise, "Train Noise")

show_examples(val_mosq, "Validation Mosquito")
show_examples(val_noise, "Validation Noise")


check_overlap(train_mosq, val_mosq, "Train Mosquito", "Val Mosquito")
check_overlap(train_noise, val_noise, "Train Noise", "Val Noise")