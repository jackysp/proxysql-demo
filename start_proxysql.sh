#!/bin/bash

# ProxySQL Demo - Traffic Shadowing Setup
# This script demonstrates how to use ProxySQL for traffic shadowing on macOS Apple Silicon

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
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop for Mac."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

check_mysql_connections() {
    log_info "Checking MySQL server connections..."
    
    # Check if MySQL servers are running on expected ports
    local mysql_a_running=false
    local mysql_b_running=false
    
    if nc -z localhost 3306 2>/dev/null; then
        mysql_a_running=true
        log_success "MySQL A (port 3306) is accessible"
    else
        log_warning "MySQL A (port 3306) is not accessible"
    fi
    
    if nc -z localhost 3307 2>/dev/null; then
        mysql_b_running=true
        log_success "MySQL B (port 3307) is accessible"
    else
        log_warning "MySQL B (port 3307) is not accessible"
    fi
    
    if [[ "$mysql_a_running" == false ]] || [[ "$mysql_b_running" == false ]]; then
        log_warning "One or both MySQL servers are not running."
        log_info "Please ensure you have MySQL servers running on:"
        log_info "  - MySQL A (Primary): localhost:3306"
        log_info "  - MySQL B (Shadow):  localhost:3307"
        log_info "You can continue anyway, but the demo may not work properly."
        
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

start_proxysql() {
    # Check if ProxySQL is already running
    if docker ps | grep -q proxysql-demo; then
        log_info "ProxySQL container is already running"
        if docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT 1" &>/dev/null; then
            log_success "ProxySQL is healthy and ready"
            return 0
        else
            log_warning "ProxySQL container exists but is not responding, restarting..."
        fi
    fi
    
    log_info "Starting ProxySQL container..."
    
    # Create sql_scripts directory if it doesn't exist
    mkdir -p sql_scripts
    
    # Use docker compose (newer) or docker-compose (older)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    # Stop any existing container (gracefully)
    $COMPOSE_CMD down 2>/dev/null || true
    
    # Start ProxySQL
    $COMPOSE_CMD up -d
    
    log_info "Waiting for ProxySQL to be ready..."
    
    # Wait for ProxySQL to be healthy
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT 1" &>/dev/null; then
            log_success "ProxySQL is ready!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "ProxySQL failed to start properly"
        exit 1
    fi
}

configure_proxysql() {
    log_info "Configuring ProxySQL..."
    
    # Check if configuration is already loaded
    local server_count
    server_count=$(docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT COUNT(*) FROM mysql_servers;" 2>/dev/null | tail -1) || server_count=0
    
    if [[ "$server_count" -gt 0 ]]; then
        log_info "ProxySQL configuration already loaded (found $server_count servers)"
        return 0
    fi
    
    # Load configuration into runtime
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        LOAD MYSQL SERVERS TO RUNTIME;
        LOAD MYSQL USERS TO RUNTIME;
        LOAD MYSQL QUERY RULES TO RUNTIME;
        LOAD MYSQL VARIABLES TO RUNTIME;
        SAVE MYSQL SERVERS TO DISK;
        SAVE MYSQL USERS TO DISK;
        SAVE MYSQL QUERY RULES TO DISK;
        SAVE MYSQL VARIABLES TO DISK;
    " 2>/dev/null
    
    log_success "ProxySQL configuration loaded"
}

show_status() {
    log_info "ProxySQL Status:"
    echo
    echo "ProxySQL Admin Interface: mysql -h127.0.0.1 -P6032 -uadmin -padmin"
    echo "ProxySQL MySQL Interface:  mysql -h127.0.0.1 -P6033 -uroot"
    echo
    
    log_info "MySQL Servers Status:"
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT hostgroup_id, hostname, port, status, weight, comment 
        FROM mysql_servers 
        ORDER BY hostgroup_id;
    " 2>/dev/null || log_warning "Could not retrieve server status"
    
    echo
    log_info "Query Rules Status:"
    docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
        SELECT rule_id, active, match_pattern, destination_hostgroup, mirror_hostgroup, comment 
        FROM mysql_query_rules 
        WHERE active=1 
        ORDER BY rule_id;
    " 2>/dev/null || log_warning "Could not retrieve query rules"
}

main() {
    echo "========================================"
    echo "    ProxySQL Traffic Shadowing Demo    "
    echo "========================================"
    echo
    
    check_prerequisites
    check_mysql_connections
    start_proxysql
    configure_proxysql
    show_status
    
    echo
    log_success "ProxySQL setup completed!"
    log_info "Use './sysbench_demo.sh' to test traffic shadowing"
    echo
    log_info "To stop ProxySQL: docker compose down"
}

# Handle script interruption
trap 'log_warning "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"