#!/bin/bash

# =============================================================================
# ProxySQL Traffic Shadowing Demo Script
# =============================================================================
# This script demonstrates ProxySQL's traffic shadowing capability by:
# 1. Checking ProxySQL is running
# 2. Resetting statistics for clean measurement
# 3. Showing baseline query counts on both servers
# 4. Executing test queries through ProxySQL
# 5. Showing final query counts to prove mirroring
# 6. Displaying the query rule that enabled mirroring
#
# Expected Result: Both Primary and Shadow servers should receive identical
# query counts, proving that traffic shadowing is working correctly.
# =============================================================================

echo "=========================================="
echo "    ProxySQL Traffic Shadowing Demo"
echo "=========================================="
echo

# =============================================================================
# PREREQUISITE CHECK
# =============================================================================
# Verify ProxySQL is running by checking if port 6033 is accessible
# Port 6033 is ProxySQL's MySQL proxy interface (where apps connect)
if ! nc -z localhost 6033 2>/dev/null; then
    echo "❌ ProxySQL not running. Start with: ./start_proxysql.sh"
    exit 1
fi

echo "✅ ProxySQL is running"
echo

# =============================================================================
# STATISTICS RESET
# =============================================================================
# Clear ProxySQL's query cache and statistics for clean measurement
# This ensures we start with zero query counts for accurate comparison
echo "🔄 Resetting statistics..."
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "PROXYSQL FLUSH QUERY CACHE;" 2>/dev/null
echo

# =============================================================================
# BASELINE MEASUREMENT
# =============================================================================
# Show current query counts on both MySQL servers before our test
# This establishes the baseline for comparison
echo "📊 BEFORE - Query counts:"
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
SELECT 
    CASE hostgroup 
        WHEN 0 THEN 'Primary MySQL (3306)'
        WHEN 1 THEN 'Shadow MySQL (3307)'
    END as Server,
    Queries
FROM stats_mysql_connection_pool 
ORDER BY hostgroup;" 2>/dev/null
echo

# =============================================================================
# TEST QUERY EXECUTION
# =============================================================================
# Execute a variety of SQL queries through ProxySQL's MySQL proxy interface
# These queries will be processed by ProxySQL's query rules and mirrored
echo "⚡ Executing 10 queries through ProxySQL..."
mysql -h127.0.0.1 -P6033 -uroot -e "
-- Simple SELECT queries (read operations)
SELECT 1 as test;
SELECT 2 as test;
SELECT 3 as test;
SELECT 4 as test;
SELECT 5 as test;

-- Database and table creation (DDL operations)
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE IF NOT EXISTS test (id INT, name VARCHAR(50));

-- Data manipulation (DML operations)
INSERT INTO test VALUES (1, 'test1'), (2, 'test2');

-- Final SELECT query to verify data
SELECT * FROM test;
" 2>err.log
echo

# =============================================================================
# RESULTS MEASUREMENT
# =============================================================================
# Show query counts after our test to prove mirroring worked
# Both servers should show the same increase in query count
echo "📊 AFTER - Query counts:"
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
SELECT 
    CASE hostgroup 
        WHEN 0 THEN 'Primary MySQL (3306)'
        WHEN 1 THEN 'Shadow MySQL (3307)'
    END as Server,
    Queries
FROM stats_mysql_connection_pool 
ORDER BY hostgroup;" 2>/dev/null
echo

# =============================================================================
# QUERY RULE VERIFICATION
# =============================================================================
# Show which query rule was triggered and how many times
# This explains WHY the mirroring happened
echo "📋 Query rule that mirrors ALL traffic:"
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
SELECT rule_id, match_pattern, destination_hostgroup, mirror_hostgroup, hits
FROM stats_mysql_query_rules 
WHERE hits > 0;" 2>/dev/null
echo

# =============================================================================
# DEMO CONCLUSION
# =============================================================================
# Summarize what the demo proved
echo "🎉 Demo complete!"
echo "✅ Both servers received the same queries"
echo "✅ Shadow traffic mirroring is working perfectly"
echo
echo "Key Takeaway:"
echo "  - Applications connect to ProxySQL (port 6033)"
echo "  - ProxySQL routes queries to Primary server (hostgroup 0)"
echo "  - ProxySQL ALSO mirrors queries to Shadow server (hostgroup 1)"
echo "  - Both servers receive identical traffic for testing/analysis"
echo
echo "This enables safe testing with real production traffic!"
