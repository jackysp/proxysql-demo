#!/bin/bash

# Helper script to set up MySQL databases for ProxySQL demo
# This script provides guidance and optional Docker setup for MySQL servers

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

show_manual_setup_instructions() {
    echo "========================================"
    echo "    MySQL Setup Instructions           "
    echo "========================================"
    echo
    
    log_info "You need two MySQL servers running on different ports:"
    echo
    echo "MySQL A (Primary Server):"
    echo "  - Host: localhost"
    echo "  - Port: 3306"
    echo "  - Root password: password"
    echo
    echo "MySQL B (Shadow Server):"
    echo "  - Host: localhost"
    echo "  - Port: 3307"
    echo "  - Root password: password"
    echo
    
    log_info "Installation options:"
    echo
    echo "Option 1 - Using Homebrew (Recommended for macOS):"
    echo "  brew install mysql"
    echo "  # Start first instance on default port 3306"
    echo "  brew services start mysql"
    echo "  # For second instance, you'll need to configure it manually"
    echo
    echo "Option 2 - Using Docker (Easier for demo):"
    echo "  # This script can set up Docker containers for you"
    echo
    echo "Option 3 - Manual installation:"
    echo "  # Download MySQL from https://dev.mysql.com/downloads/mysql/"
    echo "  # Configure two instances with different ports and data directories"
}

setup_docker_mysql() {
    log_info "Setting up MySQL servers using Docker..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop first."
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop first."
        return 1
    fi
    
    # Stop any existing MySQL containers
    docker stop mysql-primary mysql-shadow 2>/dev/null || true
    docker rm mysql-primary mysql-shadow 2>/dev/null || true
    
    log_info "Starting MySQL Primary (port 3306)..."
    docker run -d \
        --name mysql-primary \
        --platform linux/amd64 \
        -p 3306:3306 \
        -e MYSQL_ROOT_PASSWORD=password \
        -e MYSQL_DATABASE=sbtest \
        -e MYSQL_USER=sbtest \
        -e MYSQL_PASSWORD=password \
        mysql:8.0 \
        --default-authentication-plugin=mysql_native_password
    
    log_info "Starting MySQL Shadow (port 3307)..."
    docker run -d \
        --name mysql-shadow \
        --platform linux/amd64 \
        -p 3307:3306 \
        -e MYSQL_ROOT_PASSWORD=password \
        -e MYSQL_DATABASE=sbtest \
        -e MYSQL_USER=sbtest \
        -e MYSQL_PASSWORD=password \
        mysql:8.0 \
        --default-authentication-plugin=mysql_native_password
    
    log_info "Waiting for MySQL servers to start..."
    
    # Wait for both servers to be ready
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec mysql-primary mysql -uroot -ppassword -e "SELECT 1" &>/dev/null && \
           docker exec mysql-shadow mysql -uroot -ppassword -e "SELECT 1" &>/dev/null; then
            log_success "Both MySQL servers are ready!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "MySQL servers failed to start properly"
        return 1
    fi
    
    log_success "MySQL servers setup completed!"
    echo
    echo "MySQL Primary: mysql -h127.0.0.1 -P3306 -uroot -ppassword"
    echo "MySQL Shadow:  mysql -h127.0.0.1 -P3307 -uroot -ppassword"
}

test_mysql_connections() {
    log_info "Testing MySQL connections..."
    
    local primary_ok=false
    local shadow_ok=false
    
    if nc -z localhost 3306 2>/dev/null; then
        if mysql -h127.0.0.1 -P3306 -uroot -ppassword -e "SELECT 'Primary OK'" 2>/dev/null; then
            primary_ok=true
            log_success "MySQL Primary (port 3306) connection OK"
        else
            log_warning "MySQL Primary (port 3306) is running but authentication failed"
        fi
    else
        log_warning "MySQL Primary (port 3306) is not accessible"
    fi
    
    if nc -z localhost 3307 2>/dev/null; then
        if mysql -h127.0.0.1 -P3307 -uroot -ppassword -e "SELECT 'Shadow OK'" 2>/dev/null; then
            shadow_ok=true
            log_success "MySQL Shadow (port 3307) connection OK"
        else
            log_warning "MySQL Shadow (port 3307) is running but authentication failed"
        fi
    else
        log_warning "MySQL Shadow (port 3307) is not accessible"
    fi
    
    if [[ "$primary_ok" == true ]] && [[ "$shadow_ok" == true ]]; then
        log_success "Both MySQL servers are properly configured!"
        return 0
    else
        log_error "One or both MySQL servers need attention"
        return 1
    fi
}

stop_docker_mysql() {
    log_info "Stopping Docker MySQL containers..."
    
    docker stop mysql-primary mysql-shadow 2>/dev/null || true
    docker rm mysql-primary mysql-shadow 2>/dev/null || true
    
    log_success "Docker MySQL containers stopped and removed"
}

show_menu() {
    echo "========================================"
    echo "    MySQL Setup Helper                 "
    echo "========================================"
    echo
    echo "What would you like to do?"
    echo
    echo "1) Show manual setup instructions"
    echo "2) Setup MySQL using Docker (recommended for demo)"
    echo "3) Test existing MySQL connections"
    echo "4) Stop Docker MySQL containers"
    echo "5) Exit"
    echo
}

main() {
    while true; do
        show_menu
        read -p "Enter your choice (1-5): " choice
        echo
        
        case $choice in
            1)
                show_manual_setup_instructions
                echo
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_docker_mysql
                echo
                read -p "Press Enter to continue..."
                ;;
            3)
                test_mysql_connections
                echo
                read -p "Press Enter to continue..."
                ;;
            4)
                stop_docker_mysql
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1-5."
                ;;
        esac
        
        clear
    done
}

# Handle script interruption
trap 'log_warning "Script interrupted"; exit 1' INT TERM

# Check if running with arguments
if [[ $# -gt 0 ]]; then
    case $1 in
        "setup")
            setup_docker_mysql
            ;;
        "test")
            test_mysql_connections
            ;;
        "stop")
            stop_docker_mysql
            ;;
        *)
            log_error "Unknown argument: $1"
            log_info "Usage: $0 [setup|test|stop]"
            exit 1
            ;;
    esac
else
    # Run interactive menu
    main
fi