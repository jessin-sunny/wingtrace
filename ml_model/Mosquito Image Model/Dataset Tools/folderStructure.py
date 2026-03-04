import os

parent_folder = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen 3"

for root, dirs, files in os.walk(parent_folder):
    print("\nCurrent Folder:", root)
    
    for folder in dirs:
        print("Subfolder:", folder)