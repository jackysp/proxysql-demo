# ProxySQL Traffic Shadowing Demo

This repository demonstrates how to use ProxySQL for traffic shadowing on **macOS Apple Silicon**. ProxySQL acts as a proxy between your application and MySQL databases, allowing you to mirror traffic from a primary database to a shadow database for testing, monitoring, or analysis purposes.

## 🎯 What This Demo Does

- **Traffic Shadowing**: Routes primary traffic to MySQL A while mirroring (shadowing) SELECT queries to MySQL B
- **Apple Silicon Compatible**: Fully optimized for macOS with Apple Silicon (M1/M2/M3)
- **Docker-based**: Uses Docker containers for easy setup and cleanup
- **Automated Testing**: Includes sysbench validation to verify shadowing works correctly

## 📋 Prerequisites

### Required Software
- **Docker Desktop** for Mac - [Install here](https://www.docker.com/products/docker-desktop/)
- **MySQL Client** - Install via Homebrew: `brew install mysql-client`
- **Sysbench** - Install via Homebrew: `brew install sysbench`

### Required MySQL Servers
You need two MySQL servers running:
- **MySQL A (Primary)**: `localhost:3306` with root password `password`
- **MySQL B (Shadow)**: `localhost:3307` with root password `password`

Don't have MySQL servers? Use our helper script: `./setup_mysql.sh`

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <this-repo>
cd proxysql-demo
```

### 2. Setup MySQL Servers (if needed)
```bash
# Interactive setup helper
./setup_mysql.sh

# Or automated Docker setup
./setup_mysql.sh setup
```

### 3. Start ProxySQL
```bash
./start_proxysql.sh
```

### 4. Test Traffic Shadowing
```bash
./run_sysbench.sh
```

That's it! 🎉

## 📁 Project Structure

```
proxysql-demo/
├── README.md                 # This file
├── docker-compose.yml        # Docker composition for ProxySQL
├── proxysql.cnf              # ProxySQL configuration file
├── start_proxysql.sh         # Main script to start ProxySQL
├── run_sysbench.sh           # Script to validate traffic shadowing
└── setup_mysql.sh            # Helper script to setup MySQL servers
```

## ⚙️ How It Works

### ProxySQL Configuration

The demo configures ProxySQL with:

1. **MySQL Servers**:
   - Hostgroup 0: Primary server (`localhost:3306`)
   - Hostgroup 1: Shadow server (`localhost:3307`)

2. **Query Rules**:
   - `SELECT` queries → Primary server + Mirror to shadow server
   - `INSERT/UPDATE/DELETE` queries → Primary server only

3. **Users**:
   - `root` and `sbtest` users with access to both servers

### Traffic Flow

```
Application → ProxySQL (port 6033) → MySQL Primary (port 3306)
                    ↓
                    └→ MySQL Shadow (port 3307) [SELECT queries only]
```

## 🔧 Detailed Usage

### Starting ProxySQL

The `start_proxysql.sh` script:
1. ✅ Checks prerequisites (Docker, MySQL connectivity)
2. 🚀 Starts ProxySQL container using Docker Compose
3. ⚙️ Loads configuration into ProxySQL runtime
4. 📊 Shows current status and statistics

### Running Tests

The `run_sysbench.sh` script:
1. 🧪 Prepares test database and tables
2. 🏃‍♂️ Runs mixed read/write workload
3. 📖 Runs read-only workload (demonstrates mirroring)
4. 📊 Shows traffic analysis and statistics
5. 🧹 Optional cleanup of test data

### MySQL Setup Helper

The `setup_mysql.sh` script provides:
- 📋 Manual setup instructions
- 🐳 Automated Docker MySQL setup
- 🔍 Connection testing
- 🛑 Container management

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

## 🐛 Troubleshooting

### Common Issues

**ProxySQL won't start**
```bash
# Check Docker status
docker ps

# View ProxySQL logs
docker logs proxysql-demo

# Restart ProxySQL
docker compose down && docker compose up -d
```

**MySQL connection failed**
```bash
# Test MySQL connectivity
./setup_mysql.sh test

# Check if ports are in use
lsof -i :3306
lsof -i :3307
```

**Sysbench errors**
```bash
# Verify sysbench installation
sysbench --version

# Test ProxySQL connectivity
mysql -h127.0.0.1 -P6033 -uroot -ppassword -e "SELECT 1"
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

### Remove MySQL Docker Containers
```bash
./setup_mysql.sh stop
```

### Complete Cleanup
```bash
docker compose down
docker system prune -f  # Remove unused Docker resources
```

## 🔧 Configuration Customization

### Modifying MySQL Server Addresses

Edit `proxysql.cnf`:
```
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

### Customizing Query Rules

Add custom rules in `proxysql.cnf`:
```
mysql_query_rules=
(
    {
        rule_id=3
        match_pattern="^SELECT.*FROM specific_table.*"
        destination_hostgroup=0
        mirror_hostgroup=1
        apply=1
        comment="Mirror queries from specific table"
    }
)
```

## 📚 Learn More

- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [ProxySQL GitHub](https://github.com/sysown/proxysql)
- [Traffic Mirroring Best Practices](https://proxysql.com/documentation/traffic-mirroring/)

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve this demo.

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
