import os
import shutil

src_train = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\train\Culex"
src_val = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\val\Culex"
src_test = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\test\Culex"

dst_train = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\mosquito"
dst_val = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\mosquito"
dst_test = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\mosquito"

os.makedirs(dst_train, exist_ok=True)
os.makedirs(dst_val, exist_ok=True)
os.makedirs(dst_test, exist_ok=True)

def copy_all(src, dst):
    for f in os.listdir(src):
        shutil.copy(os.path.join(src, f), os.path.join(dst, f))

copy_all(src_train, dst_train)
copy_all(src_val, dst_val)
copy_all(src_test, dst_test)

print("Aedes copied successfully")