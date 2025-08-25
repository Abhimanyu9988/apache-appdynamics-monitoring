#!/bin/bash

# AppDynamics Apache Metrics Collection Script
SERVERS=(
    "localhost"
    $(hostname -I | awk '{print $1}')
)

collect_apache_metrics() {
    local server="$1"
    local server_name="$2"

    # Try HTTP first (since Apache is running on port 80)
    local endpoints=(
        "http://$server/server-status?auto"
        "https://$server/server-status?auto"
    )

    local metrics_data=""

    # Try each endpoint until one works
    for endpoint in "${endpoints[@]}"; do
        metrics_data=$(curl -k -s --connect-timeout 10 --max-time 30 "$endpoint" 2>/dev/null)

        if [[ $? -eq 0 && -n "$metrics_data" && "$metrics_data" != *"<html>"* && "$metrics_data" == *"ServerVersion"* ]]; then
            break
        fi
    done

    # Check if we got valid metrics data
    if [[ -z "$metrics_data" || "$metrics_data" == *"<html>"* ]]; then
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Status,value=0"
        return 1
    fi

    # Server is responding - mark as up
    echo "name=Custom Metrics|Apache Monitor|${server_name}|Status,value=1"

    # Parse and output all the metrics in AppDynamics format

    # Server Load Metrics (multiply by 100 for whole numbers)
    local load1=$(echo "$metrics_data" | grep "^Load1:" | cut -d' ' -f2 | head -1)
    local load5=$(echo "$metrics_data" | grep "^Load5:" | cut -d' ' -f2 | head -1)
    local load15=$(echo "$metrics_data" | grep "^Load15:" | cut -d' ' -f2 | head -1)

    if [[ -n "$load1" ]]; then
        load1=$(awk "BEGIN {printf \"%.0f\", $load1 * 100}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Load Average|1 Minute x100,value=$load1"
    fi
    if [[ -n "$load5" ]]; then
        load5=$(awk "BEGIN {printf \"%.0f\", $load5 * 100}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Load Average|5 Minutes x100,value=$load5"
    fi
    if [[ -n "$load15" ]]; then
        load15=$(awk "BEGIN {printf \"%.0f\", $load15 * 100}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Load Average|15 Minutes x100,value=$load15"
    fi

    # Request Metrics
    local total_accesses=$(echo "$metrics_data" | grep "^Total Accesses:" | cut -d' ' -f3 | head -1)
    local req_per_sec=$(echo "$metrics_data" | grep "^ReqPerSec:" | cut -d' ' -f2 | head -1)

    [[ -n "$total_accesses" ]] && echo "name=Custom Metrics|Apache Monitor|${server_name}|Requests|Total Accesses,value=$total_accesses"

    if [[ -n "$req_per_sec" ]]; then
        req_per_sec=$(awk "BEGIN {printf \"%.0f\", $req_per_sec * 1000}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Requests|Requests Per 1000 Seconds,value=$req_per_sec"
    fi

    # Traffic Metrics
    local total_kbytes=$(echo "$metrics_data" | grep "^Total kBytes:" | cut -d' ' -f3 | head -1)
    local bytes_per_sec=$(echo "$metrics_data" | grep "^BytesPerSec:" | cut -d' ' -f2 | head -1)
    local bytes_per_req=$(echo "$metrics_data" | grep "^BytesPerReq:" | cut -d' ' -f2 | head -1)

    [[ -n "$total_kbytes" ]] && echo "name=Custom Metrics|Apache Monitor|${server_name}|Traffic|Total KBytes,value=$total_kbytes"

    if [[ -n "$bytes_per_sec" ]]; then
        bytes_per_sec=$(awk "BEGIN {printf \"%.0f\", $bytes_per_sec}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Traffic|Bytes Per Second,value=$bytes_per_sec"
    fi

    if [[ -n "$bytes_per_req" ]]; then
        bytes_per_req=$(awk "BEGIN {printf \"%.0f\", $bytes_per_req}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Traffic|Bytes Per Request,value=$bytes_per_req"
    fi

    # CPU Metrics
    local cpu_user=$(echo "$metrics_data" | grep "^CPUUser:" | cut -d' ' -f2 | head -1)
    local cpu_system=$(echo "$metrics_data" | grep "^CPUSystem:" | cut -d' ' -f2 | head -1)

    if [[ -n "$cpu_user" ]]; then
        cpu_user=$(awk "BEGIN {printf \"%.0f\", $cpu_user * 100}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|CPU|CPU User Percent x100,value=$cpu_user"
    fi
    if [[ -n "$cpu_system" ]]; then
        cpu_system=$(awk "BEGIN {printf \"%.0f\", $cpu_system * 100}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|CPU|CPU System Percent x100,value=$cpu_system"
    fi

    # Worker Metrics - USE HEAD -1 to get only first occurrence
    local busy_workers=$(echo "$metrics_data" | grep "^BusyWorkers:" | cut -d' ' -f2 | head -1)
    local idle_workers=$(echo "$metrics_data" | grep "^IdleWorkers:" | cut -d' ' -f2 | head -1)

    [[ -n "$busy_workers" ]] && echo "name=Custom Metrics|Apache Monitor|${server_name}|Workers|Busy Workers,value=$busy_workers"
    [[ -n "$idle_workers" ]] && echo "name=Custom Metrics|Apache Monitor|${server_name}|Workers|Idle Workers,value=$idle_workers"

    # Calculate total workers and utilization percentage
    if [[ -n "$busy_workers" && -n "$idle_workers" ]]; then
        local total_workers=$((busy_workers + idle_workers))
        local worker_utilization=0
        if [[ $total_workers -gt 0 ]]; then
            worker_utilization=$(awk "BEGIN {printf \"%.0f\", $busy_workers * 100 / $total_workers}")
        fi
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Workers|Total Workers,value=$total_workers"
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Workers|Worker Utilization Percent,value=$worker_utilization"
    fi

    # Uptime Metrics
    local uptime_seconds=$(echo "$metrics_data" | grep "^ServerUptimeSeconds:" | cut -d' ' -f2 | head -1)
    if [[ -n "$uptime_seconds" ]]; then
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Server|Uptime Seconds,value=$uptime_seconds"
        local uptime_days=$(awk "BEGIN {printf \"%.0f\", $uptime_seconds / 86400}")
        echo "name=Custom Metrics|Apache Monitor|${server_name}|Server|Uptime Days,value=$uptime_days"
    fi

    return 0
}

# Main execution
main() {
    if ! command -v curl &> /dev/null; then
        echo "name=Custom Metrics|Apache Monitor|Script|Error,value=1"
        exit 1
    fi

    local server_count=0
    local successful_collections=0

    for server in "${SERVERS[@]}"; do
        server_count=$((server_count + 1))
        local server_name=$(echo "$server" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

        if collect_apache_metrics "$server" "$server_name"; then
            successful_collections=$((successful_collections + 1))
        fi
    done

    # Summary metrics
    echo "name=Custom Metrics|Apache Monitor|Script|Total Servers,value=$server_count"
    echo "name=Custom Metrics|Apache Monitor|Script|Successful Collections,value=$successful_collections"
    echo "name=Custom Metrics|Apache Monitor|Script|Failed Collections,value=$((server_count - successful_collections))"

    if [[ $successful_collections -eq $server_count ]]; then
        echo "name=Custom Metrics|Apache Monitor|Script|Health Status,value=1"
    else
        echo "name=Custom Metrics|Apache Monitor|Script|Health Status,value=0"
    fi
}

main "$@"
