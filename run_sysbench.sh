#!/bin/bash

# Sysbench validation script for ProxySQL traffic shadowing
# This script runs sysbench to validate that traffic shadowing is working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if sysbench is installed
    if ! command -v sysbench &> /dev/null; then
        log_error "Sysbench is not installed."
        log_info "Please install sysbench:"
        log_info "  On macOS: brew install sysbench"
        log_info "  On Ubuntu: sudo apt-get install sysbench"
        exit 1
    fi
    
    # Check if ProxySQL is running
    if ! nc -z localhost 6033 2>/dev/null; then
        log_error "ProxySQL is not running on port 6033"
        log_info "Please run './start_proxysql.sh' first"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

prepare_test_database() {
    log_info "Preparing test database..."
    
    # Create database and user through ProxySQL
    mysql -h127.0.0.1 -P6033 -uroot -ppassword -e "
        DROP DATABASE IF EXISTS sbtest;
        CREATE DATABASE sbtest;
        GRANT ALL PRIVILEGES ON sbtest.* TO 'sbtest'@'%' IDENTIFIED BY 'password';
        FLUSH PRIVILEGES;
    " 2>/dev/null || {
        log_warning "Could not create database through ProxySQL"
        log_info "Please ensure MySQL servers are running and accessible"
        return 1
    }
    
    log_success "Test database prepared"
}

run_sysbench_prepare() {
    log_info "Preparing sysbench tables..."
    
    sysbench \
        --db-driver=mysql \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=sbtest \
        --mysql-password=password \
        --mysql-db=sbtest \
        --tables=4 \
        --table-size=10000 \
        oltp_read_write \
        prepare
    
    log_success "Sysbench tables prepared"
}

monitor_query_stats() {
    log_info "Monitoring ProxySQL query statistics..."
    
    # Show initial stats
    echo "=== Before Test ==="
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT hostgroup, srv_host, srv_port, Queries, Bytes_sent, Bytes_recv
        FROM stats_mysql_connection_pool
        ORDER BY hostgroup, srv_host, srv_port;
    " 2>/dev/null || log_warning "Could not retrieve connection stats"
}

run_sysbench_test() {
    log_info "Running sysbench workload test..."
    
    # Run a mixed read/write workload
    sysbench \
        --db-driver=mysql \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=sbtest \
        --mysql-password=password \
        --mysql-db=sbtest \
        --tables=4 \
        --threads=4 \
        --time=30 \
        --report-interval=10 \
        oltp_read_write \
        run
    
    log_success "Sysbench test completed"
}

show_traffic_analysis() {
    log_info "Analyzing traffic distribution..."
    
    echo
    echo "=== After Test ==="
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT hostgroup, srv_host, srv_port, Queries, Bytes_sent, Bytes_recv
        FROM stats_mysql_connection_pool
        ORDER BY hostgroup, srv_host, srv_port;
    " 2>/dev/null || log_warning "Could not retrieve connection stats"
    
    echo
    echo "=== Query Rules Statistics ==="
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT rule_id, hits, match_pattern, destination_hostgroup, mirror_hostgroup
        FROM stats_mysql_query_rules
        WHERE hits > 0
        ORDER BY rule_id;
    " 2>/dev/null || log_warning "Could not retrieve query rules stats"
    
    echo
    echo "=== Command Statistics ==="
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT Command, Total_cnt, Total_Time_us
        FROM stats_mysql_commands_counters
        WHERE Total_cnt > 0
        ORDER BY Total_cnt DESC;
    " 2>/dev/null || log_warning "Could not retrieve command stats"
}

run_read_only_test() {
    log_info "Running read-only test to validate shadowing..."
    
    # Run read-only workload to see mirroring in action
    log_info "Executing SELECT queries that should be mirrored..."
    
    sysbench \
        --db-driver=mysql \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=sbtest \
        --mysql-password=password \
        --mysql-db=sbtest \
        --tables=4 \
        --threads=2 \
        --time=15 \
        --report-interval=5 \
        oltp_read_only \
        run
    
    log_success "Read-only test completed"
}

cleanup_test() {
    log_info "Cleaning up test data..."
    
    sysbench \
        --db-driver=mysql \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=sbtest \
        --mysql-password=password \
        --mysql-db=sbtest \
        --tables=4 \
        oltp_read_write \
        cleanup 2>/dev/null || log_warning "Cleanup may have failed"
    
    log_success "Test cleanup completed"
}

main() {
    echo "========================================"
    echo "    ProxySQL Traffic Shadowing Test    "
    echo "========================================"
    echo
    
    check_prerequisites
    prepare_test_database
    run_sysbench_prepare
    
    echo
    log_info "Starting traffic shadowing validation..."
    
    monitor_query_stats
    
    # Run mixed workload
    run_sysbench_test
    
    # Run read-only workload to better demonstrate mirroring
    run_read_only_test
    
    show_traffic_analysis
    
    echo
    log_success "Traffic shadowing validation completed!"
    echo
    log_info "Key observations:"
    log_info "1. Hostgroup 0 (primary) should show both read and write queries"
    log_info "2. Hostgroup 1 (shadow) should show mirrored SELECT queries"
    log_info "3. Query rules should show hits for both primary and mirror rules"
    echo
    
    read -p "Do you want to clean up test data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_test
    else
        log_info "Test data preserved. You can clean up later with:"
        log_info "  sysbench --mysql-host=127.0.0.1 --mysql-port=6033 --mysql-user=sbtest --mysql-password=password --mysql-db=sbtest --tables=4 oltp_read_write cleanup"
    fi
}

# Handle script interruption
trap 'log_warning "Test interrupted"; exit 1' INT TERM

# Run main function
main "$@"