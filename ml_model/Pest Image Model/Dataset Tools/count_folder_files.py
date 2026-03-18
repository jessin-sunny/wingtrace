import os

dataset_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\Dataset"

for split in ["train","val","test"]:

    print("\n",split.upper())

    split_path = os.path.join(dataset_path,split)

    total=0

    for cls in os.listdir(split_path):

        class_path = os.path.join(split_path,cls)

        count = len(os.listdir(class_path))

        total += count

        print(f"{cls} : {count}")

    print("Total:",total)