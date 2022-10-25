#!/bin/zsh

# svg2icns - Set the containing folder icon to the SVG image.
# Flavien Scheurer 2022

# Declare variables.
# App name and copyright information.
app_name="svg2icns"
author="© 2022 Flavien Scheurer https://github.com/Ystorian/svg2any"

# App version, uses the script file date by default.
version="$(stat -f %Sm -t %Y-%m-%d "$0")"

# Log file.
log_file="$HOME/Library/Logs/$app_name.log"

# Image size in pixels.
size=1024

# Use the version from the bundle if available.
if [[ -f "$PWD/../Info.plist" ]]; then
	version="$(plutil -extract CFBundleShortVersionString raw "$PWD/../Info.plist")"
fi

# Prune the log file if larger than 1 MB.
if [[ -f "$log_file" ]]; then
	find "$log_file" -size +1M -delete
fi

# Test if a file was selected.
if [[ "$1" = "" ]]; then
	# No file selected, assuming we are running as a standalone script, display the help text.
	echo "$app_name version $version"
	echo "Set the containing folder icon to the SVG image"
	echo "The converted file will be a hidden icon resource in the same directory."
	echo "\n\tUsage: $app_name file"
	exit
fi

# Log the app name, version, and path.
echo "\n\n$(date +"%Y-%m-%d %H:%M:%S") $app_name version $version" >>"$log_file"
echo "Running script: $0" >>"$log_file"

# Define the file variables.

# Supported file extensions.
input_ext=svg
output_ext=png

# Base directory path.
base_dir=$(dirname "$1")

# Input file name.
input_file_name=$(basename "$1")

# Base file name without any extension.
base_file=$(basename "$1" .$input_ext)
base_file=${base_file%.*}

# Output file name.
output_file_name=$base_file.$output_ext

# Icon file path.
icon_path="$base_dir"/Icon$'\r'

# Temp directory.
temp_dir="$(mktemp -d)"

# Temp directory for iconutil, must be named with the .iconset suffix.
iconset_dir="$temp_dir/$base_file.iconset"

# Create the temp directory.
mkdir "$iconset_dir"

# Test if the input file exists.
if [[ ! -f "$base_dir/$input_file_name" ]]; then
	echo "Error: File not found: $base_dir/$input_file_name" | tee -a "$log_file"
	exit
fi

echo "Base directory: $base_dir" >>"$log_file"
echo "Input file: $input_file_name" >>"$log_file"
echo "Output file: $output_file_name" >>"$log_file"

# Test if the output file already exists.
if [[ -f "$icon_path" ]]; then
	echo "Overwriting existing folder icon." | tee -a "$log_file"
	rm "$icon_path"
fi

# Define the 10 default icon sizes in a macOS .ICNS file.
# https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/app-icon/
# https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html
icon_sizes=(16,16x16 32,16x16@2x 32,32x32 64,32x32@2x 128,128x128 256,128x128@2x 256,256x256 512,256x256@2x 512,512x512 1024,512x512@2x)

# Create a PNG file for each icon_sizes.
for sizes in $icon_sizes; do
	size=$(echo $sizes | cut -d, -f1)
	label=$(echo $sizes | cut -d, -f2)
	png_file_name="icon_$label.png"
	# Convert with rsvg-convert.
	echo "Creating $png_file_name ($size x $size)..." | tee -a "$log_file"
	./rsvg-convert --width=$size --height=$size --keep-aspect-ratio "$base_dir/$input_file_name" \
		--output "$iconset_dir/$png_file_name" &>>"$log_file"
	# Test if the output file was created.
	if [[ ! -f "$iconset_dir/$png_file_name" ]]; then
		echo "Error: Output not found: $iconset_dir/$png_file_name" | tee -a "$log_file"
		exit
	fi
done

# Convert the PNG files to an ICNS file.
iconutil --convert icns --output "$temp_dir/$base_file.icns" "$iconset_dir" &>>"$log_file"

# Create the icon with the extended attribute "com.apple.ResourceFork".
echo "read 'icns' (-16455) \"$temp_dir/$base_file.icns\";\n" | rez -p -o "$icon_path" &>>/dev/null

# Set the base folder to show the icon.
setfile -a C "$base_dir" &>>"$log_file"

# Hide the icon.
setfile -a V "$icon_path" &>>"$log_file"

# Clean the temp dirs.
rm -rf "$temp_dir"

# Display the path and size of the output file.
echo "Created an icon in $base_dir" | tee -a "$log_file"
echo "$(date +"%Y-%m-%d %H:%M:%S") Done." >>"$log_file"
