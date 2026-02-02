# Testing Dockerized Trino with Custom Changes

This guide explains how to build, deploy, and test a Dockerized Trino server with your local code changes.

## Quick Start

```bash
# Full automated cycle: build → image → deploy → test
make dev-test
```

## Workflow Overview

```
Your Changes → Maven Build → Docker Image → Deploy Container → Run Tests
     ↑                                                              |
     └────────────────── Iterate ←──────────────────────────────────┘
```

## Prerequisites

1. **Docker installed and running**
2. **Maven and Java** (see [DEVELOPMENT.md](../.github/DEVELOPMENT.md))
3. **Python 3.6+** with pip (for testing)

## Step-by-Step Guide

### Step 1: Make Your Changes

Edit Trino source code as needed:
- Core changes: `core/trino-main/src/...`
- Connector changes: `plugin/<connector>/src/...`
- CLI changes: `client/trino-cli/src/...`

### Step 2: Build From Source

```bash
# Full build (first time or after major changes)
make dev-build

# Or incremental build (faster for small changes)
make dev-build-fast
```

This creates:
- `core/trino-server/target/trino-server-480-SNAPSHOT.tar.gz`
- `client/trino-cli/target/trino-cli-480-SNAPSHOT-executable.jar`

**Build time:** 15-30 minutes (first time), 5-10 minutes (incremental)

### Step 3: Build Docker Image

```bash
# Build Docker image using your local artifacts
make build-docker
```

This runs `core/docker/build.sh` which:
1. Extracts the server tarball
2. Copies the CLI jar
3. Builds multi-arch Docker images
4. Creates image: `trino:480-SNAPSHOT`

**Build time:** 2-5 minutes

**Verify image:**
```bash
docker images | grep trino
```

### Step 4: Deploy Custom Image

```bash
# Deploy your custom Trino image
make deploy-custom

# Or manual docker command:
docker run -d \
  --name trino-server \
  -p 8080:8080 \
  -v $(pwd)/trino-config:/etc/trino \
  trino:480-SNAPSHOT
```

**Check status:**
```bash
make status
```

**View logs:**
```bash
make logs
```

### Step 5: Test Your Changes

```bash
# Setup Python test environment (first time only)
make test-setup

# Run Python tests
make test-python

# Run Docker health checks
make test-docker

# Quick smoke test
make quick-test
```

**Manual testing with CLI:**
```bash
# Use container CLI
make cli

# Or use locally built CLI
make dev-cli

# Or run queries directly
docker exec trino-server trino --execute "SELECT * FROM tpch.tiny.nation LIMIT 5"
```

## Makefile Targets Reference

| Target | Purpose | When to Use |
|--------|---------|-------------|
| `make dev-build` | Build Trino from source | First time, major changes |
| `make dev-build-fast` | Incremental Maven build | Small changes |
| `make build-docker` | Build Docker image with your changes | After Maven build |
| `make deploy-custom` | Deploy your custom image | Testing your changes |
| `make test-python` | Run Python integration tests | Validate functionality |
| `make test-docker` | Run Docker health checks | Validate container health |
| `make dev-test` | Full cycle: build→image→deploy→test | Complete validation |
| `make restart-custom` | Rebuild and redeploy | Iterative testing |

## Iterative Development Workflow

For rapid iteration during development:

```bash
# 1. Make code changes
vim core/trino-main/src/.../YourClass.java

# 2. Fast rebuild
make dev-build-fast

# 3. Rebuild Docker image
make build-docker-quick

# 4. Restart container with new image
make restart-custom

# 5. Test
make test-python

# 6. Repeat...
```

**Total cycle time:** 5-10 minutes per iteration (after initial build)

## Testing Strategies

### Strategy 1: Python Integration Tests

Create custom tests in `tests/python/`:

```python
# tests/python/test_my_feature.py
import pytest
import trino

class TestMyFeature:
    @pytest.fixture
    def conn(self):
        return trino.dbapi.connect(
            host="localhost", port=8080, user="test",
            catalog="tpch", schema="tiny"
        )
    
    def test_my_change(self, conn):
        cur = conn.cursor()
        cur.execute("SELECT your_new_function()")
        result = cur.fetchone()
        assert result[0] == expected_value
```

Run: `make test-python`

### Strategy 2: Docker Health Tests

```bash
# Test container health endpoint
make test-docker

# Test specific functionality
docker exec trino-server trino --catalog tpch --schema tiny \
  --execute "SELECT COUNT(*) FROM nation"
```

### Strategy 3: Manual CLI Testing

```bash
# Interactive session
make cli

# Run inside container:
trino> USE tpch.tiny;
trino> SELECT * FROM nation LIMIT 5;
trino> EXPLAIN ANALYZE SELECT ...;
```

### Strategy 4: JDBC Testing

```python
# test_jdbc.py
import jaydebeapi

conn = jaydebeapi.connect(
    "io.trino.jdbc.TrinoDriver",
    "jdbc:trino://localhost:8080/tpch/tiny",
    ["test-user", ""],
    "client/trino-jdbc/target/trino-jdbc-480-SNAPSHOT.jar"
)
cursor = conn.cursor()
cursor.execute("SELECT * FROM nation")
print(cursor.fetchall())
```

## Debugging Failed Tests

### Trino Won't Start

```bash
# Check container logs
make logs

# Check for port conflicts
docker ps | grep 8080

# Verify config
ls -la trino-config/
cat trino-config/config.properties
```

### Tests Can't Connect

```bash
# Verify Trino is healthy
make quick-test

# Check from inside container
docker exec trino-server /usr/lib/trino/bin/health-check

# Manual curl test
curl http://localhost:8080/v1/info
```

### Build Failures

```bash
# Clean and rebuild
./mvnw clean
make dev-build

# Check specific module
./mvnw install -pl core/trino-main -am -DskipTests
```

## Advanced: Testing Specific Changes

### Testing Connector Changes

```bash
# Add catalog for your connector
cat > trino-config/catalog/myconnector.properties << EOF
connector.name=my-connector
connection-url=jdbc:...
EOF

# Restart with new config
make restart-custom

# Test connector
make cli
trino> SHOW CATALOGS;
trino> USE myconnector.public;
```

### Testing Server Configuration Changes

```bash
# Edit config
cat >> trino-config/config.properties << EOF
query.max-memory=8GB
query.max-stage-count=150
EOF

# Restart to apply
make restart-custom
```

### Testing Security Changes

```bash
# Enable authentication in config
echo "http-server.authentication.type=PASSWORD" >> trino-config/config.properties

# Add password file
echo "test-user:$2y$10$..." >> trino-config/password.db

# Restart and test with credentials
make restart-custom
python tests/python/test_auth.py  # Custom auth test
```

## Performance Testing

```python
# tests/python/test_performance.py
import time
import trino

def test_query_performance():
    conn = trino.dbapi.connect(host="localhost", port=8080, user="test")
    cur = conn.cursor()
    
    start = time.time()
    cur.execute("SELECT COUNT(*) FROM tpch.sf100.lineitem")
    result = cur.fetchone()
    elapsed = time.time() - start
    
    print(f"Query completed in {elapsed:.2f}s")
    assert elapsed < 30.0, "Query too slow!"
```

## Comparing Against Official Image

Test your changes vs. official release:

```bash
# Test official version
make deploy
make test-python > results-official.txt
make stop

# Test your version
make deploy-custom
make test-python > results-custom.txt
make stop

# Compare
diff results-official.txt results-custom.txt
```

## Continuous Integration Testing

Add to your GitHub Actions:

```yaml
# .github/workflows/test-docker.yml
name: Test Dockerized Trino
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      
      - name: Build Trino
        run: make dev-build
      
      - name: Build Docker image
        run: make build-docker-quick
      
      - name: Deploy and test
        run: make dev-test
```

## Cleanup

```bash
# Stop and remove container
make stop

# Clean images
make clean

# Deep clean (removes all build cache)
make prune
```

## Quick Reference Card

```bash
# First time setup
make dev-build build-docker test-setup

# Daily workflow
make dev-build-fast build-docker-quick deploy-custom test-python

# Testing
make deploy-custom test-python  # Custom image
make deploy test-python          # Official image
make quick-test                  # Health check

# Debugging
make status    # Check container
make logs      # View logs
make cli       # Interactive shell
```

## Troubleshooting Checklist

- [ ] Maven build succeeded without errors
- [ ] Docker image shows in `docker images`
- [ ] Container is running (`make status`)
- [ ] Port 8080 not in use by another process
- [ ] Trino health check passes (`make quick-test`)
- [ ] Python dependencies installed (`make test-setup`)
- [ ] Tests using correct connection parameters
- [ ] No firewall blocking localhost:8080

## Further Resources

- [Trino Docker README](../core/docker/README.md)
- [Development Guide](../.github/DEVELOPMENT.md)
- [Testing Guide](../testing/README.md)
- [Trino Python Client](https://github.com/trinodb/trino-python-client)
