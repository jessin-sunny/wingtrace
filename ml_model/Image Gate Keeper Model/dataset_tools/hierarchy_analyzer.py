import os

root_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset"

total_images = 0

for root, dirs, files in os.walk(root_path):

    level = root.replace(root_path, "").count(os.sep)
    indent = " " * 4 * level
    folder_name = os.path.basename(root)

    images = [f for f in files if f.lower().endswith((".jpg",".jpeg",".png",".bmp",".tif",".tiff"))]
    #images = [f for f in files if f.lower().endswith((".wav"))]
    img_count = len(images)

    if img_count > 0:
        total_images += img_count
        print(f"{indent}{folder_name}  ->  {img_count} images")
    else:
        print(f"{indent}{folder_name}/")

print("\nTotal images found:", total_images)