# set-rating

Nautilus right-click script to set star ratings on images via exiftool.

Writes `XMP:Rating` (0=unrated, 1-5) into the selected files. If a
darktable sidecar (`<file>.<ext>.xmp`) exists the rating goes there;
otherwise it is written directly into the image file.

## Requirements

- lua5.3 (or similar)
- exiftool
- zenity

Install on openSUSE:

    sudo zypper install lua53 exiftool zenity

Install on Debian/Ubuntu:

    sudo apt install lua5.3 libimage-exiftool-perl zenity

## Install

    cp set-rating.lua ~/.local/share/nautilus/scripts/"Set Rating.lua"
    chmod +x ~/.local/share/nautilus/scripts/"Set Rating.lua"

Right-click an image in Nautilus → Scripts → **Set Rating.lua**.

## darktable

darktable keeps metadata in its own database and ignores external XMP
changes while running. To pick up the new rating:

- **Preferences → Storage → XMP → enable "look for updated xmp files
  on startup"**, then restart darktable. A dialog will offer to reload
  the modified sidecars into the database.

## License

MIT
