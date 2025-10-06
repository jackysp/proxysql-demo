#!/bin/bash

# ProxySQL Read-Only Performance Demo
# Generates read-only database traffic through ProxySQL with traffic shadowing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
TEST_DB="perf_test"
TEST_TABLES=5
TEST_ROWS=1000
TEST_DURATION=300
THREADS=4

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_perf() {
    echo -e "${PURPLE}[PERF]${NC} $1"
}

echo "ProxySQL Read-Only Performance Demo"
echo

# Check if ProxySQL is running
if ! nc -z localhost 6033 2>/dev/null; then
    log_error "ProxySQL not running. Start with: ./start_proxysql.sh"
    exit 1
fi
log_success "ProxySQL is running"

# Ensure database exists (re-enterable)
log_info "Ensuring test database exists..."
mysql -h127.0.0.1 -P6033 -uroot -e "CREATE DATABASE IF NOT EXISTS $TEST_DB;" >/dev/null 2>&1 || true

# Setup test database and tables
log_info "Setting up test database and tables..."

# Create or truncate test tables (re-enterable)
log_info "Creating or truncating $TEST_TABLES test tables with $TEST_ROWS rows each..."
for i in $(seq 1 $TEST_TABLES); do
    mysql -h127.0.0.1 -P6033 -uroot -e "
    USE $TEST_DB;
    CREATE TABLE IF NOT EXISTS test_table_$i (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100),
        email VARCHAR(100),
        age INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name),
        INDEX idx_email (email),
        INDEX idx_age (age)
    );
    TRUNCATE TABLE test_table_$i;" >/dev/null 2>&1
    
    # Insert test data
    mysql -h127.0.0.1 -P6033 -uroot -e "
    USE $TEST_DB;
    INSERT INTO test_table_$i (name, email, age) 
    SELECT 
        CONCAT('User_', n, '_', $i) as name,
        CONCAT('user_', n, '_', $i, '@example.com') as email,
        FLOOR(RAND() * 80) + 18 as age
    FROM (
        SELECT a.N + b.N * 10 + c.N * 100 + d.N * 1000 + 1 n
        FROM 
        (SELECT 0 as N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
        (SELECT 0 as N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
        (SELECT 0 as N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c,
        (SELECT 0 as N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
    ) t
    WHERE n <= $TEST_ROWS;" >/dev/null 2>&1
done

log_success "Test database and tables created successfully"
echo

# Run read-only performance test
run_readonly_test() {
    local duration="$1"
    local threads="$2"
    
    log_perf "Running Read-Only workload (threads: $threads, duration: ${duration}s)..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Run test in background threads
    for ((i=1; i<=threads; i++)); do
        (
            while [ $(date +%s) -lt $end_time ]; do
                # Read-only workload
                mysql -h127.0.0.1 -P6033 -uroot -e "
                USE $TEST_DB;
                SELECT COUNT(*) FROM test_table_$((RANDOM % TEST_TABLES + 1)) WHERE age > 30;
                SELECT * FROM test_table_$((RANDOM % TEST_TABLES + 1)) WHERE name LIKE 'User_%' LIMIT 10;
                SELECT AVG(age) FROM test_table_$((RANDOM % TEST_TABLES + 1));
                " >/dev/null 2>&1
                sleep 0.1
            done
        ) &
    done
    
    # Wait for all background jobs to complete
    wait
    
    local actual_duration=$(($(date +%s) - start_time))
    log_success "Read-Only workload completed in ${actual_duration}s"
}

# Monitor ProxySQL stats
monitor_proxysql_stats() {
    log_info "ProxySQL Statistics:"
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
    SELECT 
        CASE hostgroup 
            WHEN 0 THEN 'Primary MySQL (3306)'
            WHEN 1 THEN 'Shadow MySQL (3307)'
        END as Server,
        Queries,
        ConnOK,
        ConnERR
    FROM stats_mysql_connection_pool 
    ORDER BY hostgroup;" 2>/dev/null
}

# Start read-only performance test
log_info "Starting read-only performance test..."
run_readonly_test $TEST_DURATION $THREADS
monitor_proxysql_stats

# Preserve data for re-runs
log_success "Read-only performance test complete! (data preserved for next run)"
