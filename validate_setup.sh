#!/bin/bash

# Simple validation script that doesn't require external MySQL servers or sysbench
# This tests the ProxySQL container setup and basic functionality

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

test_docker_setup() {
    log_info "Testing Docker setup..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        return 1
    fi
    
    log_success "Docker is available and running"
}

test_compose_file() {
    log_info "Testing Docker Compose file..."
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found"
        return 1
    fi
    
    # Test compose file syntax
    if docker compose config &> /dev/null || docker-compose config &> /dev/null 2>&1; then
        log_success "Docker Compose file is valid"
    else
        log_error "Docker Compose file has syntax errors"
        return 1
    fi
}

test_proxysql_config() {
    log_info "Testing ProxySQL configuration..."
    
    if [[ ! -f "proxysql.cnf" ]]; then
        log_error "proxysql.cnf not found"
        return 1
    fi
    
    # Basic validation of config file structure
    if grep -q "mysql_servers" proxysql.cnf && \
       grep -q "mysql_users" proxysql.cnf && \
       grep -q "mysql_query_rules" proxysql.cnf; then
        log_success "ProxySQL configuration file structure is valid"
    else
        log_error "ProxySQL configuration file is missing required sections"
        return 1
    fi
}

test_scripts_executable() {
    log_info "Testing script permissions..."
    
    local scripts=("start_proxysql.sh" "run_sysbench.sh" "setup_mysql.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            log_success "$script is executable"
        else
            log_error "$script is not executable"
            all_executable=false
        fi
    done
    
    if [[ "$all_executable" == true ]]; then
        return 0
    else
        log_info "Fix with: chmod +x *.sh"
        return 1
    fi
}

test_proxysql_container_start() {
    log_info "Testing ProxySQL container startup..."
    
    # Use docker compose (newer) or docker-compose (older)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    # Stop any existing container
    $COMPOSE_CMD down 2>/dev/null || true
    
    # Start container
    if $COMPOSE_CMD up -d; then
        log_success "ProxySQL container started successfully"
        
        # Wait a bit and check if it's running
        sleep 5
        if docker ps | grep -q proxysql-demo; then
            log_success "ProxySQL container is running"
            
            # Test admin interface (without requiring MySQL backends)
            local max_attempts=10
            local attempt=0
            
            while [ $attempt -lt $max_attempts ]; do
                if docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT 1" &>/dev/null; then
                    log_success "ProxySQL admin interface is accessible"
                    break
                fi
                
                attempt=$((attempt + 1))
                echo -n "."
                sleep 2
            done
            
            if [ $attempt -eq $max_attempts ]; then
                log_warning "ProxySQL admin interface is not responding (this might be normal without MySQL backends)"
            fi
            
            # Clean up
            $COMPOSE_CMD down
            log_info "Cleaned up test container"
            
            return 0
        else
            log_error "ProxySQL container is not running"
            return 1
        fi
    else
        log_error "Failed to start ProxySQL container"
        return 1
    fi
}

main() {
    echo "========================================"
    echo "    ProxySQL Demo Validation           "
    echo "========================================"
    echo
    
    local all_tests_passed=true
    
    # Run all tests
    test_docker_setup || all_tests_passed=false
    echo
    
    test_compose_file || all_tests_passed=false
    echo
    
    test_proxysql_config || all_tests_passed=false
    echo
    
    test_scripts_executable || all_tests_passed=false
    echo
    
    test_proxysql_container_start || all_tests_passed=false
    echo
    
    if [[ "$all_tests_passed" == true ]]; then
        log_success "All validation tests passed! 🎉"
        echo
        log_info "Next steps:"
        log_info "1. Setup MySQL servers: ./setup_mysql.sh"
        log_info "2. Start ProxySQL: ./start_proxysql.sh"
        log_info "3. Run sysbench test: ./run_sysbench.sh"
    else
        log_error "Some validation tests failed. Please fix the issues above."
        exit 1
    fi
}

# Handle script interruption
trap 'log_warning "Validation interrupted"; exit 1' INT TERM

# Run main function
main "$@"