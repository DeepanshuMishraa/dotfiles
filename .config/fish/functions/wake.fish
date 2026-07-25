function wake -d "Prevent macOS system sleep"
    sudo pmset -a disablesleep 1
end
