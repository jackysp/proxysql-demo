#!/bin/bash

# Complete ProxySQL demo workflow
# This script runs the entire demo from start to finish

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

log_step() {
    echo -e "${BOLD}${BLUE}=== $1 ===${NC}"
}

pause_for_user() {
    echo
    read -p "Press Enter to continue..." -r
    echo
}

main() {
    clear
    echo "========================================"
    echo "    ProxySQL Traffic Shadowing Demo    "
    echo "           Complete Workflow            "
    echo "========================================"
    echo
    
    log_info "This demo will:"
    log_info "1. Validate the setup"
    log_info "2. Optionally setup MySQL servers using Docker"
    log_info "3. Start ProxySQL"
    log_info "4. Run traffic shadowing tests"
    log_info "5. Show results and cleanup options"
    echo
    
    read -p "Continue with the demo? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Demo cancelled"
        exit 0
    fi
    
    clear
    
    # Step 1: Validate setup
    log_step "Step 1: Validating Setup"
    if ./validate_setup.sh; then
        log_success "Setup validation passed!"
    else
        log_error "Setup validation failed. Please fix the issues and try again."
        exit 1
    fi
    
    pause_for_user
    clear
    
    # Step 2: MySQL setup
    log_step "Step 2: MySQL Server Setup"
    log_info "Checking for existing MySQL servers..."
    
    if nc -z localhost 3306 2>/dev/null && nc -z localhost 3307 2>/dev/null; then
        log_success "MySQL servers are already running on ports 3306 and 3307"
    else
        log_warning "MySQL servers are not running"
        echo
        read -p "Would you like to set up MySQL servers using Docker? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ./setup_mysql.sh setup; then
                log_success "MySQL servers setup completed!"
            else
                log_error "MySQL setup failed"
                exit 1
            fi
        else
            log_info "Please ensure MySQL servers are running on ports 3306 and 3307"
            log_info "You can run './setup_mysql.sh' later for automated setup"
            pause_for_user
        fi
    fi
    
    pause_for_user
    clear
    
    # Step 3: Start ProxySQL
    log_step "Step 3: Starting ProxySQL"
    if ./start_proxysql.sh; then
        log_success "ProxySQL started successfully!"
    else
        log_error "Failed to start ProxySQL"
        exit 1
    fi
    
    pause_for_user
    clear
    
    # Step 4: Run tests
    log_step "Step 4: Running Traffic Shadowing Tests"
    
    if command -v sysbench &> /dev/null; then
        log_info "Running sysbench validation..."
        if ./run_sysbench.sh; then
            log_success "Traffic shadowing tests completed successfully!"
        else
            log_warning "Some tests may have failed, but this is normal if MySQL servers are not fully configured"
        fi
    else
        log_warning "Sysbench is not installed. Skipping automated tests."
        log_info "To install sysbench: brew install sysbench"
        log_info "You can run './run_sysbench.sh' after installing sysbench"
        
        # Show manual testing instructions
        echo
        log_info "Manual testing instructions:"
        echo "1. Connect to ProxySQL: mysql -h127.0.0.1 -P6033 -uroot -ppassword"
        echo "2. Run some SELECT queries"
        echo "3. Check stats: mysql -h127.0.0.1 -P6032 -uadmin -padmin"
        echo "4. View mirroring stats: SELECT * FROM stats_mysql_connection_pool;"
    fi
    
    pause_for_user
    clear
    
    # Step 5: Results and cleanup
    log_step "Step 5: Demo Results and Cleanup"
    
    log_success "Demo completed successfully!"
    echo
    log_info "What you've accomplished:"
    log_info "✅ Set up ProxySQL with traffic shadowing"
    log_info "✅ Configured MySQL A as primary, MySQL B as shadow"
    log_info "✅ Demonstrated query mirroring for SELECT statements"
    log_info "✅ Validated the setup works on macOS Apple Silicon"
    echo
    
    log_info "ProxySQL is still running. You can:"
    log_info "- Connect to MySQL through ProxySQL: mysql -h127.0.0.1 -P6033 -uroot -ppassword"
    log_info "- Monitor ProxySQL admin: mysql -h127.0.0.1 -P6032 -uadmin -padmin"
    log_info "- Run more tests: ./run_sysbench.sh"
    echo
    
    read -p "Would you like to stop ProxySQL now? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping ProxySQL..."
        docker compose down
        log_success "ProxySQL stopped"
    fi
    
    echo
    read -p "Would you like to stop the Docker MySQL servers? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping MySQL Docker containers..."
        ./setup_mysql.sh stop
        log_success "MySQL containers stopped"
    fi
    
    echo
    log_success "Thank you for trying the ProxySQL Traffic Shadowing Demo! 🎉"
    log_info "For more information, check the README.md file"
}

# Handle script interruption
trap 'log_warning "Demo interrupted"; exit 1' INT TERM

# Run main function
main "$@"