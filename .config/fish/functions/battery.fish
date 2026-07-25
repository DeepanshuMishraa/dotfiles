function battery -d "Show battery percentage and remaining time"
    pmset -g batt | grep -oE "[0-9]+%;.*[0-9]+:[0-9]+ remaining" | sed "s/ discharging; //"
end
