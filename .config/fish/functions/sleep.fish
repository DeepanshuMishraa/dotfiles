function sleep -d "Allow macOS system sleep"
    sudo pmset -a disablesleep 0
end
