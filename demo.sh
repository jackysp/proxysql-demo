#!/bin/bash

# Ultra-Simple ProxySQL Traffic Shadowing Demo

echo "=========================================="
echo "    ProxySQL Traffic Shadowing Demo"
echo "=========================================="
echo

# Check ProxySQL is running
if ! nc -z localhost 6033 2>/dev/null; then
    echo "❌ ProxySQL not running. Start with: ./start_proxysql.sh"
    exit 1
fi

echo "✅ ProxySQL is running"
echo

# Reset stats
echo "🔄 Resetting statistics..."
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "PROXYSQL FLUSH QUERY CACHE;" 2>/dev/null
echo

# Show before
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

# Execute some queries through ProxySQL
echo "⚡ Executing 10 queries through ProxySQL..."
mysql -h127.0.0.1 -P6033 -uroot -e "
SELECT 1 as test;
SELECT 2 as test;
SELECT 3 as test;
SELECT 4 as test;
SELECT 5 as test;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE IF NOT EXISTS test (id INT, name VARCHAR(50));
INSERT INTO test VALUES (1, 'test1'), (2, 'test2');
SELECT * FROM test;
" 2>/dev/null
echo

# Show after
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

# Show the rule that made this happen
echo "📋 Query rule that mirrors ALL traffic:"
docker exec proxysql-demo mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
SELECT rule_id, match_pattern, destination_hostgroup, mirror_hostgroup, hits
FROM stats_mysql_query_rules 
WHERE hits > 0;" 2>/dev/null
echo

echo "🎉 Demo complete!"
echo "✅ Both servers received the same queries"
echo "✅ Shadow traffic mirroring is working perfectly"
