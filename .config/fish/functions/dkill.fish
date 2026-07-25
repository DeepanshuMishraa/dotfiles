function dkill -d "Stop all running Docker containers"
    docker stop (docker ps -q)
end
