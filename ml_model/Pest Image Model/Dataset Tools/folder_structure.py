import os

dataset_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\Dataset"

total_images = 0

for species in os.listdir(dataset_path):
    species_path = os.path.join(dataset_path, species)
    
    if os.path.isdir(species_path):
        images = [f for f in os.listdir(species_path)
                  if f.lower().endswith(('.jpg','.jpeg','.png'))]
        
        count = len(images)
        total_images += count
        
        print(f"{species} : {count} images")

print("\nTotal species:", len(os.listdir(dataset_path)))
print("Total images:", total_images)