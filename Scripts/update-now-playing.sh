#!/bin/bash

# GitHub Gist Configuration
GIST_ID="93919a95a814e2206452b8c96a7595a8"
# Load token from config file (not checked into git)
CONFIG_DIR="$HOME/.config/nowplaying"
if [ -f "$CONFIG_DIR/env" ]; then
    . "$CONFIG_DIR/env"
fi

# Get current track info from Apple Music using AppleScript
get_music_info() {
    osascript << 'EOF'
tell application "System Events"
    if not (exists process "Music") then
        return "NOT_RUNNING"
    end if
end tell

tell application "Music"
    if player state is not playing and player state is not paused then
        return "NOT_PLAYING"
    end if

    try
        set trackName to name of current track
        set trackArtist to artist of current track
        set trackAlbum to album of current track
        set isPlaying to (player state is playing)
        return trackName & "<<SEP>>" & trackArtist & "<<SEP>>" & trackAlbum & "<<SEP>>" & isPlaying
    on error
        return "ERROR"
    end try
end tell
EOF
}

# Main logic
MUSIC_INFO=$(get_music_info)

if [[ "$MUSIC_INFO" == "NOT_RUNNING" ]] || [[ "$MUSIC_INFO" == "NOT_PLAYING" ]] || [[ "$MUSIC_INFO" == "ERROR" ]]; then
    # No music playing
    JSON_CONTENT="{\"isPlaying\":false,\"track\":null,\"artist\":null,\"album\":null,\"albumArt\":null,\"updatedAt\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
else
    # Parse the music info
    TRACK=$(echo "$MUSIC_INFO" | awk -F'<<SEP>>' '{print $1}')
    ARTIST=$(echo "$MUSIC_INFO" | awk -F'<<SEP>>' '{print $2}')
    ALBUM=$(echo "$MUSIC_INFO" | awk -F'<<SEP>>' '{print $3}')
    IS_PLAYING=$(echo "$MUSIC_INFO" | awk -F'<<SEP>>' '{print $4}')

    # Convert to Python boolean string
    if [[ "$IS_PLAYING" == "true" ]]; then
        IS_PLAYING_PY="True"
    else
        IS_PLAYING_PY="False"
    fi

    # Create JSON using python for proper escaping
    JSON_CONTENT=$(python3 << PYEOF
import json
data = {
    'isPlaying': $IS_PLAYING_PY,
    'track': """$TRACK""",
    'artist': """$ARTIST""",
    'album': """$ALBUM""",
    'albumArt': None,
    'updatedAt': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
}
print(json.dumps(data))
PYEOF
)
fi

# Update the Gist
ESCAPED_JSON=$(echo "$JSON_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')

RESPONSE=$(curl -s -X PATCH \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/gists/$GIST_ID" \
    -d "{\"files\":{\"now-playing.json\":{\"content\":$ESCAPED_JSON}}}")

# Check if update was successful
if echo "$RESPONSE" | grep -q "now-playing.json"; then
    echo "$(date): Updated - $TRACK by $ARTIST"
else
    echo "$(date): Failed to update gist"
    echo "$RESPONSE"
fi
