import os

SEGMENT_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest_2.0_Segments"

total = 0

for cls in os.listdir(SEGMENT_PATH):
    cls_path = os.path.join(SEGMENT_PATH, cls)
    if os.path.isdir(cls_path):
        count = len([f for f in os.listdir(cls_path) if f.endswith(".wav")])
        print(f"{cls}: {count}")
        total += count

print("\nTotal segments:", total)