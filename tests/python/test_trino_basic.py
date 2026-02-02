"""
Basic connectivity and query tests for Trino server.

Prerequisites:
    pip install trino pytest

Usage:
    pytest test_trino_basic.py -v
"""

import pytest
import trino


class TestTrinoBasic:
    """Basic connectivity and query tests for Trino server."""
    
    @pytest.fixture(scope="class")
    def trino_client(self):
        """Create a Trino client connection."""
        conn = trino.dbapi.connect(
            host="localhost",
            port=8080,
            user="test-user",
            catalog="tpch",
            schema="tiny"
        )
        yield conn
        conn.close()
    
    @pytest.fixture(scope="class")
    def trino_cursor(self, trino_client):
        """Create a cursor from the connection."""
        cursor = trino_client.cursor()
        yield cursor
        cursor.close()
    
    def test_connection(self, trino_client):
        """Test basic connectivity to Trino server."""
        assert trino_client is not None
        print("✓ Connected to Trino server")
    
    def test_simple_query(self, trino_cursor):
        """Test executing a simple query."""
        trino_cursor.execute("SELECT 1")
        result = trino_cursor.fetchone()
        assert result[0] == 1
        print("✓ Simple query executed successfully")
    
    def test_tpch_nation_table(self, trino_cursor):
        """Test querying TPCH nation table."""
        trino_cursor.execute("SELECT COUNT(*) FROM nation")
        result = trino_cursor.fetchone()
        assert result[0] == 25  # TPCH tiny nation table has 25 rows
        print(f"✓ TPCH nation table has {result[0]} rows")
    
    def test_tpch_region_table(self, trino_cursor):
        """Test querying TPCH region table."""
        trino_cursor.execute("SELECT name FROM region ORDER BY regionkey")
        results = trino_cursor.fetchall()
        assert len(results) == 5  # TPCH tiny has 5 regions
        print(f"✓ TPCH region table has {len(results)} rows")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
