#!/bin/bash

# ProxySQL Real-Time Performance Monitor
# Usage: ./monitor_performance.sh [interval_seconds]

# Configuration
INTERVAL=${1:-5}

# Keep output minimal (no colors)

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}


# Display current interval QPS and latency
show_latency_stats() {
    local elapsed="$1"
    local ts="$(get_timestamp)"
    # Guard: avoid divide-by-zero
    if [ -z "$elapsed" ] || [ "$elapsed" = "0" ]; then
        elapsed="1"
    fi
    # Query per-hostgroup QPS and latency (since last reset)
    local output
    output=$(docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
    SELECT 
      d.hostgroup,
      ROUND(SUM(d.count_star) / ${elapsed}, 2) AS qps,
      ROUND(AVG(d.sum_time/d.count_star) / 1000, 2) AS lat_ms
    FROM stats_mysql_query_digest d
    WHERE d.hostgroup IN (0,1) AND d.count_star > 0
    GROUP BY d.hostgroup
    ORDER BY d.hostgroup;" 2>/dev/null | tail -n +2)

    local p_qps p_lat s_qps s_lat
    if [ -z "$output" ]; then
        p_qps=0; p_lat=NULL; s_qps=0; s_lat=NULL
    else
        p_qps=$(echo "$output" | awk 'NR==1{print $2}'); [ -z "$p_qps" ] && p_qps=0
        p_lat=$(echo "$output" | awk 'NR==1{print $3}'); [ -z "$p_lat" ] && p_lat=NULL
        s_qps=$(echo "$output" | awk 'NR==2{print $2}'); [ -z "$s_qps" ] && s_qps=0
        s_lat=$(echo "$output" | awk 'NR==2{print $3}'); [ -z "$s_lat" ] && s_lat=NULL
    fi

    echo "${ts} | Primary:QPS=${p_qps} Lat=${p_lat}ms | Shadow:QPS=${s_qps} Lat=${s_lat}ms"
}

# Reset ProxySQL stats for fresh interval
reset_proxysql_stats() {
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT * FROM stats_mysql_query_digest_reset;" >/dev/null 2>&1
}



# Main monitoring loop
main() {
    # Check if ProxySQL is running
    if ! nc -z localhost 6033 2>/dev/null; then
        echo "ProxySQL not running. Start with: ./start_proxysql.sh"
        exit 1
    fi
    
    # Check if docker container exists
    if ! docker ps | grep -q proxysql-demo; then
        echo "ProxySQL container not found. Start with: ./start_proxysql.sh"
        exit 1
    fi
    
    echo "Starting real-time performance monitoring..."
    echo "Press Ctrl+C to stop monitoring"
    
    # Main monitoring loop
    # Prime: ensure we start a fresh interval
    reset_proxysql_stats

    while true; do
        # Measure precise elapsed time across the interval
        local start_ns=$(date +%s%N)
        sleep $INTERVAL
        local end_ns=$(date +%s%N)
        local elapsed_ns=$((end_ns - start_ns))
        # Convert to fractional seconds with millisecond precision
        local elapsed_s=$(awk "BEGIN{printf \"%.3f\", ${elapsed_ns}/1000000000}")

        show_latency_stats "$elapsed_s"
        reset_proxysql_stats
    done
}

# Handle script interruption
trap 'echo "\nMonitoring stopped by user"; exit 0' INT TERM

# Show usage if help requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "ProxySQL Real-Time Performance Monitor"
    echo
    echo "Usage: $0 [interval_seconds]"
    echo
    echo "Arguments:"
    echo "  interval_seconds  Update interval in seconds (default: 5)"
    echo
    echo "Examples:"
    echo "  $0              # Monitor with 5-second intervals"
    echo "  $0 2            # Monitor with 2-second intervals"
    echo "  $0 10           # Monitor with 10-second intervals"
    echo
    echo "Features:"
    echo "  - Real-time performance and latency monitoring"
    echo "  - Query execution statistics"
    echo "  - Primary vs Shadow server comparison"
    echo
    exit 0
fi

# Run main function
main "$@"
