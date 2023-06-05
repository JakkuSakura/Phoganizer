# Phoganizer
Organize photos by exif

## Usage
```shell
brew install exiftool # MacOS, other OS refers to https://exiftool.org/
pip install -e phoganizer
python -m phoganizer path/to/photos
```
It will rename photos to `YYYY-MM-DD_HH-MM-SS.N.jpg` format and move them to `path/to/photos/YYYY-MM-DD` folder.
