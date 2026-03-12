import os
import random
import time
from gradio_client import Client, handle_file

# Connect to HuggingFace Space
client = Client("wingtrace/wingmodel")

DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito Unseen 3"
# DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Image\Pest Unseen"

classes = ["AEDES", "CULEX", "ANOPHELES"]
# classes = ["Cicadellidae",
        # "Lycorma delicatula",
        # "Mirdae",
        # "Aphids",
        # "Blister beetle",
        # "Corn borer",
        # "Whitefly"]

samples_per_class = 10

total = 0
correct = 0

class_correct = {c:0 for c in classes}

for cls in classes:

    folder = os.path.join(DATASET_PATH, cls)

    images = os.listdir(folder)

    # randomly pick 100 images
    selected = random.sample(images, samples_per_class)

    print(f"\nTesting class: {cls}")

    for img in selected:

        img_path = os.path.join(folder, img)

        try:

            result = client.predict(
                image=handle_file(img_path),
                api_name="/predict_bug"
            )

            print(img, "->", result)

            if "Aedes" in result:
                pred = "AEDES"
            elif "Culex" in result:
                pred = "CULEX"
            elif "Anopheles" in result:
                pred = "ANOPHELES"
            else:
                pred = "OTHER"

            total += 1

            if pred == cls:
                correct += 1
                class_correct[cls] += 1

        except Exception as e:
            print("Error:", e)

        time.sleep(1)  # prevent API rate limit

print("\n==========================")
print("RESULTS")

for c in classes:
    print(f"{c} accuracy:", class_correct[c], "/ 100")

print("\nTotal Images:", total)
print("Correct:", correct)
print("Overall Accuracy:", (correct/total)*100, "%")