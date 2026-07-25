function dps -d "List Docker containers in a formatted table"
    begin
        printf "CONTAINER ID\tIMAGE\tCREATED AT\tSTATUS\tNAMES\n"
        docker ps -a --format "{{.ID}}\t{{.Image}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Names}}" | sort -k3 -r
    end | column -t
end
