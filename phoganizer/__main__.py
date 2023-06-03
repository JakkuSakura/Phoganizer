from PIL import Image, ExifTags
import os
import shutil
import tqdm
import argparse
import exiftool
# return iterator of each image file in directory recursively
def get_image_files(path):
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png', '.arw')):
                yield os.path.join(root, file)

def get_exif_data(image):
    with exiftool.ExifToolHelper() as et:
        metadata = et.get_metadata(image)
        for d in metadata:
            return d

def get_shoot_time(image_exif):
    return image_exif["EXIF:DateTimeOriginal"]


counts = {}
def get_image_filename(image_exif, old_filename):
    """
    Return a new filename for the image based on the shoot time
    format: YYYY-MM-DD_HH-MM-SS.N.{jpg/arw}
    """
    tm = get_shoot_time(image_exif).replace(':', '-').replace(' ', '_')
    if tm in counts:
        counts[tm] += 1
    else:
        counts[tm] = 0
    num = counts[tm]
    ext = old_filename.split('.')[-1]
    return tm + '.' + str(num) + '.' + ext




def main():
    parser = argparse.ArgumentParser(description='Organize photos by date')
    parser.add_argument('path', metavar='path', type=str, help='path to directory of photos')
    args = parser.parse_args()
    path = args.path

    for filename in tqdm.tqdm(get_image_files(path)):
        try:
            image_exif = get_exif_data(filename)
            shoot_time = get_shoot_time(image_exif)
            dir_name = shoot_time.split(' ')[0].replace(':', '-')
            file_name = get_image_filename(image_exif, filename)
            dest = os.path.join(path, dir_name, file_name)
            os.makedirs(os.path.join(path, dir_name), exist_ok=True)
            print('moving', filename, 'to', dest)
            shutil.move(filename, dest)

            xmp_file = filename.replace('.jpg', '.xmp')
            if os.path.exists(xmp_file):
                xmp_dest = dest.replace('.jpg', '.arw')
                print('moving', filename, 'to', xmp_dest)
                shutil.move(xmp_file, xmp_dest)
        except Exception as e:
            print(e)
            print('failed to move', filename)

if __name__ == '__main__':
    main()


