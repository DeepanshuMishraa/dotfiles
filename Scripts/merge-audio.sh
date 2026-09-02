#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") VIDEO AUDIO [OUTPUT]" >&2
    echo "If OUTPUT is omitted, writes VIDEO_WITH_AUDIO next to VIDEO." >&2
    exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

video=$1
audio=$2

[[ -f "$video" ]] || { echo "Video file not found: $video" >&2; exit 1; }
[[ -f "$audio" ]] || { echo "Audio file not found: $audio" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required." >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe is required." >&2; exit 1; }

if [[ $# -eq 3 ]]; then
    output=$3
else
    video_dir=${video%/*}
    [[ "$video_dir" == "$video" ]] && video_dir=.
    video_name=${video##*/}
    video_stem=${video_name%.*}
    video_ext=${video_name##*.}
    [[ "$video_stem" == "$video_name" ]] && video_ext=mkv
    output="$video_dir/${video_stem}_with_audio.${video_ext}"
fi

[[ "$output" != "$video" ]] || { echo "OUTPUT must differ from VIDEO." >&2; exit 1; }
[[ "$output" != "$audio" ]] || { echo "OUTPUT must differ from AUDIO." >&2; exit 1; }

video_duration=$(LC_ALL=C ffprobe \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$video") || {
    echo "Could not read the video duration: $video" >&2
    exit 1
}

if ! awk -v duration="$video_duration" 'BEGIN { exit !(duration > 0) }'; then
    echo "Could not determine a valid video duration: $video_duration" >&2
    exit 1
fi

if [[ -e "$output" ]]; then
    echo "Output already exists: $output" >&2
    echo "Choose another output path or remove it first." >&2
    exit 1
fi

output_extension=${output##*.}
[[ "$output" == *.* ]] || output_extension=mkv
tmp_output="${output}.partial.$$.${output_extension}"
cleanup() {
    rm -f "$tmp_output"
}
trap cleanup EXIT INT TERM

# Copy the video stream. Only the audio is encoded, so the video packets are
# unchanged. atrim limits long audio without shortening a video with short audio.
ffmpeg -hide_banner -n \
    -i "$video" \
    -i "$audio" \
    -filter_complex "[1:a:0]atrim=duration=${video_duration},asetpts=PTS-STARTPTS[audio]" \
    -map 0:v:0 \
    -map '[audio]' \
    -map_metadata 0 \
    -c:v copy \
    -c:a aac -b:a 192k \
    "$tmp_output"

mv "$tmp_output" "$output"
trap - EXIT INT TERM
printf 'Created: %s\n' "$output"
