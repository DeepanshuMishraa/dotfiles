#!/bin/bash

echo -n "Enter YouTube URL: "
read url

echo -n "Enter start timestamp (e.g., 4:20): "
read start

echo -n "Enter end timestamp (e.g., 4:43): "
read end

echo -n "Format (mp3/mp4): "
read format

output_dir="$HOME/Downloads"

if [[ "$format" == "mp3" ]]; then
    yt-dlp -x --audio-format mp3 -o "$output_dir/%(title)s.%(ext)s" --download-sections "*${start}-${end}" "$url"
else
    yt-dlp -f "best[ext=mp4]" -o "$output_dir/%(title)s.%(ext)s" --download-sections "*${start}-${end}" "$url"
fi
