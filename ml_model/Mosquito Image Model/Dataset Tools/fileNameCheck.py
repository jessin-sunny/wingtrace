import os

# Dataset path
dataset_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito"

# Loop through each class folder
for class_name in os.listdir(dataset_path):
    class_path = os.path.join(dataset_path, class_name)

    if os.path.isdir(class_path):
        print(f"\nClass: {class_name}")

        files = os.listdir(class_path)

        # Show first 20 filenames
        for file in files[:50]:
            print(file)