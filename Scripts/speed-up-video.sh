#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") VIDEO_PATH" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage

video=$1
[[ -f "$video" ]] || { echo "Video file not found: $video" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required." >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe is required." >&2; exit 1; }

has_audio=false
if ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$video" | grep -q .; then
    has_audio=true
fi

read -r -p "Speed multiplier (for example, 1.8 or 2): " speed

if [[ ! "$speed" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] || ! awk -v speed="$speed" 'BEGIN { exit !(speed > 0) }'; then
    echo "Speed must be a number greater than 0." >&2
    exit 2
fi

video_name=${video##*/}
video_stem=${video_name%.*}
output_dir="$HOME/Downloads"
output="$output_dir/${video_stem}_${speed}x.mp4"

mkdir -p "$output_dir"
[[ "$output" != "$video" ]] || { echo "Output must differ from the input video." >&2; exit 1; }
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }

tmp_output="${output}.partial.$$.mp4"
cleanup() {
    rm -f "$tmp_output"
}
trap cleanup EXIT INT TERM

if awk -v speed="$speed" 'BEGIN { exit !(speed == 1) }'; then
    ffmpeg -hide_banner -n -i "$video" -map 0 -map_metadata 0 -c copy "$tmp_output"
else
    # atempo accepts values from 0.5 to 2.0, so split larger changes into stages.
    atempo=$(awk -v speed="$speed" 'BEGIN {
        value = speed
        while (value > 2) { printf "atempo=2,"; value /= 2 }
        while (value < 0.5) { printf "atempo=0.5,"; value /= 0.5 }
        printf "atempo=%.12g", value
    }')

    if [[ "$has_audio" == true ]]; then
        ffmpeg -hide_banner -n \
            -i "$video" \
            -filter_complex "[0:v:0]setpts=PTS/${speed}[video];[0:a:0]${atempo}[audio]" \
            -map '[video]' \
            -map '[audio]' \
            -map_metadata 0 \
            -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
            -c:a aac -b:a 192k \
            -movflags +faststart \
            "$tmp_output"
    else
        ffmpeg -hide_banner -n \
            -i "$video" \
            -filter:v "setpts=PTS/${speed}" \
            -map 0:v:0 \
            -map_metadata 0 \
            -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
            -movflags +faststart \
            "$tmp_output"
    fi
fi

mv "$tmp_output" "$output"
printf 'Created: %s\n' "$output"
