# ProxySQL Traffic Shadowing Demo

This repository demonstrates how to use ProxySQL for traffic shadowing on **macOS Apple Silicon**. ProxySQL acts as a proxy between your application and MySQL databases, allowing you to mirror traffic from a primary database to a shadow database for testing, monitoring, or analysis purposes.

## 🎯 What This Demo Does

- **Traffic Shadowing**: Routes primary traffic to MySQL A while mirroring (shadowing) ALL queries to MySQL B
- **Performance Monitoring**: Comprehensive performance and latency analysis using sysbench workloads
- **Real-time Monitoring**: Live performance metrics and connection pool statistics
- **Apple Silicon Compatible**: Fully optimized for macOS with Apple Silicon (M1/M2/M3)
- **Docker-based**: Uses Docker containers for easy setup and cleanup
- **Multiple Demo Types**: Simple traffic validation and comprehensive performance testing

## 📋 Prerequisites

### Required Software

- **Docker Desktop** for Mac - [Install here](https://www.docker.com/products/docker-desktop/)
- **MySQL Client** - Install via Homebrew: `brew install mysql-client`

### Required MySQL Servers

You need two MySQL servers running:

- **MySQL A (Primary)**: `localhost:3306` with root user (no password)
- **MySQL B (Shadow)**: `localhost:3307` with root user (no password)

**Note**: You'll need to set up these MySQL servers separately before running the ProxySQL demo.

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <this-repo>
cd proxysql-demo
```

### 2. Start ProxySQL

```bash
./start_proxysql.sh
```

### 3. Test Traffic Shadowing

Choose your demo type:

```bash
# Simple traffic shadowing demo (reentrant - safe to run multiple times)
./demo.sh

# OR comprehensive performance & latency monitoring demo
./performance_demo_simple.sh
```

### 4. Real-time Monitoring (Optional)

In another terminal, monitor performance in real-time:

```bash
./monitor_performance.sh
```

That's it! 🎉

## 📁 Project Structure

```text
proxysql-demo/
├── README.md                    # This file
├── PERFORMANCE_DEMO.md          # Detailed performance demo documentation
├── docker-compose.yml           # Docker composition for ProxySQL  
├── proxysql.cnf                 # Minimal ProxySQL configuration (heavily commented)
├── start_proxysql.sh            # Start ProxySQL (reentrant)
├── demo.sh                      # Simple traffic demo (reentrant)
├── performance_demo_simple.sh   # Comprehensive performance & latency demo
└── monitor_performance.sh       # Real-time performance monitoring
```

## ⚙️ How It Works

### ProxySQL Configuration

The demo configures ProxySQL with:

1. **MySQL Servers**:
   - Hostgroup 0: Primary server (`localhost:3306`)
   - Hostgroup 1: Shadow server (`localhost:3307`)

2. **Query Rules**:
   - `ALL` queries → Primary server + Mirror to shadow server

3. **Users**:
   - `root` user with access to both servers

### Traffic Flow

```text
Application → ProxySQL (port 6033) → MySQL Primary (port 3306)
                    ↓
                    └→ MySQL Shadow (port 3307) [ALL queries mirrored]
```

## 🔧 Detailed Usage

### Starting ProxySQL

The `start_proxysql.sh` script:

1. ✅ Checks prerequisites (Docker, MySQL connectivity)
2. 🚀 Starts ProxySQL container using Docker Compose
3. ⚙️ Loads configuration into ProxySQL runtime
4. 📊 Shows current status and statistics

### Demo Workflows

**Simple Traffic Demo (`demo.sh`)**:

1. ✅ Checks if ProxySQL is running
2. 🧹 Resets ProxySQL statistics for clean results
3. 📊 Shows BEFORE query counts (both servers)
4. ⚡ Executes 10 mixed queries through ProxySQL
5. 📊 Shows AFTER query counts (proving mirroring)
6. 📋 Shows the query rule that enables mirroring

**Performance Demo (`performance_demo_simple.sh`)**:

1. ✅ Checks prerequisites (ProxySQL, MySQL servers)
2. 🧹 Resets statistics and cleans up test data
3. 📊 Collects baseline performance measurements
4. 🔧 Sets up test database and tables with realistic data
5. ⚡ Runs multiple workload tests (read-only, write-only, mixed, high concurrency)
6. 🔍 Performs detailed latency analysis
7. 📈 Collects comprehensive performance statistics
8. 🔄 Verifies traffic mirroring between servers
9. 🧹 Cleans up test data

**Real-time Monitoring (`monitor_performance.sh`)**:

1. ✅ Checks ProxySQL connectivity
2. 📊 Displays real-time connection pool statistics
3. 📈 Shows query distribution and hit rates
4. 🔄 Verifies traffic mirroring status
5. ⚡ Provides performance summary metrics
6. 💻 Monitors system resources
7. 🔧 Shows ProxySQL process information

**Start ProxySQL (`start_proxysql.sh`)**:

1. ✅ Checks prerequisites (Docker)
2. 🔍 Detects if ProxySQL is already running
3. 🚀 Starts or restarts ProxySQL container as needed
4. ⚙️ Loads configuration (only if not already loaded)
5. 📊 Shows current status

## 📊 Monitoring and Analysis

### ProxySQL Admin Interface

```bash
# Connect to ProxySQL admin interface
mysql -h127.0.0.1 -P6032 -uadmin -padmin

# View server statistics
SELECT * FROM stats_mysql_connection_pool;

# View query rule statistics
SELECT * FROM stats_mysql_query_rules;
```

### Key Metrics to Watch

1. **Connection Pool Stats**: Shows query distribution between servers
2. **Query Rule Hits**: Shows how many queries matched each rule
3. **Command Counters**: Shows types of SQL commands executed
4. **Shadow Traffic Ratio**: Percentage of queries mirrored to shadow server
5. **Backend Performance**: Response times and error rates per server

### Validation Checklist

To verify shadow traffic is working correctly:

✅ **Hostgroup 0 (Primary)**: Should receive all queries (reads + writes)  
✅ **Hostgroup 1 (Shadow)**: Should receive all mirrored queries  
✅ **Query Rules**: Mirror rule should show hits with mirror_hostgroup=1  
✅ **Shadow Ratio**: Should be ~100% (ALL queries are mirrored)  
✅ **No Errors**: Connection pools should show ConnERR=0

## 🐛 Troubleshooting

### Common Issues

#### ProxySQL won't start

```bash
# Check Docker status
docker ps

# View ProxySQL logs
docker logs proxysql-demo

# Restart ProxySQL
docker compose down && docker compose up -d
```

#### MySQL connection failed

```bash
# Check if ports are in use
lsof -i :3306
lsof -i :3307

# Test direct MySQL connectivity
mysql -h127.0.0.1 -P3306 -uroot -e "SELECT 1"
mysql -h127.0.0.1 -P3307 -uroot -e "SELECT 1"
```

#### Demo errors

```bash
# Test ProxySQL connectivity
mysql -h127.0.0.1 -P6033 -uroot -e "SELECT 1"

# Check if ProxySQL is running
docker ps | grep proxysql-demo
```

### Port Conflicts

If you have existing MySQL installations:

- Default MySQL usually runs on port 3306
- You may need to stop it: `brew services stop mysql`
- Or configure different ports in `proxysql.cnf`

## 🧹 Cleanup

### Stop ProxySQL

```bash
docker compose down
```

### Clean Up Demo Data

```bash
# Clean up demo database
mysql -h127.0.0.1 -P6033 -uroot -e "DROP DATABASE IF EXISTS demo;"
```

### Complete Cleanup

```bash
docker compose down
docker system prune -f  # Remove unused Docker resources
```

## 🔧 Configuration Customization

### Modifying MySQL Server Addresses

Edit `proxysql.cnf`:

```text
mysql_servers=
(
    {
        address="your-mysql-primary-host"
        port=3306
        hostgroup=0
        # ... other settings
    },
    {
        address="your-mysql-shadow-host"
        port=3307
        hostgroup=1
        # ... other settings
    }
)
```

## 📚 Learn More

- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [ProxySQL GitHub](https://github.com/sysown/proxysql)
- [Traffic Mirroring Best Practices](https://proxysql.com/documentation/traffic-mirroring/)
- [Performance Demo Documentation](PERFORMANCE_DEMO.md) - Detailed guide for performance monitoring

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve this demo.

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
