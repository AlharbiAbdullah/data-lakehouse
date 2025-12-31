"""
Set up DuckDB warehouse with external tables pointing to raw parquet files.

Creates views for each data source that dbt can reference.
"""

from pathlib import Path

import duckdb

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
WAREHOUSE_DIR = PROJECT_ROOT / "data" / "warehouse"
DB_PATH = WAREHOUSE_DIR / "lakehouse.duckdb"


def setup_warehouse() -> None:
    """Create DuckDB database and set up external tables."""
    print("=" * 60)
    print("DuckDB Warehouse Setup")
    print("=" * 60)
    print()

    # Ensure warehouse directory exists
    WAREHOUSE_DIR.mkdir(parents=True, exist_ok=True)

    # Check if raw data exists
    parquet_files = list(RAW_DATA_DIR.glob("*.parquet"))
    if not parquet_files:
        print("[ERROR] No parquet files found in data/raw/")
        print("        Run 'python scripts/download_data.py' first.")
        return

    print(f"Database path: {DB_PATH}")
    print(f"Raw data directory: {RAW_DATA_DIR}")
    print()

    # Connect to DuckDB (creates file if doesn't exist)
    conn = duckdb.connect(str(DB_PATH))

    try:
        # Create schema for raw data
        conn.execute("CREATE SCHEMA IF NOT EXISTS raw")
        print("[OK] Created schema: raw")

        # Create views for each trip type
        trip_types = {
            "yellow_tripdata": "Yellow taxi trips",
            "green_tripdata": "Green taxi trips",
            "fhv_tripdata": "For-hire vehicle trips",
        }

        for trip_type, description in trip_types.items():
            files = list(RAW_DATA_DIR.glob(f"{trip_type}_*.parquet"))
            if files:
                # Create a view that reads all parquet files for this type
                file_pattern = str(RAW_DATA_DIR / f"{trip_type}_*.parquet")
                conn.execute(f"""
                    CREATE OR REPLACE VIEW raw.{trip_type} AS
                    SELECT * FROM read_parquet('{file_pattern}')
                """)

                # Get row count
                result = conn.execute(f"SELECT COUNT(*) FROM raw.{trip_type}").fetchone()
                row_count = result[0] if result else 0

                print(f"[OK] Created view: raw.{trip_type}")
                print(f"     {description}: {row_count:,} rows")
            else:
                print(f"[SKIP] No files found for {trip_type}")

        # Create view for taxi zones (from CSV)
        zones_file = RAW_DATA_DIR / "taxi_zone_lookup.csv"
        if zones_file.exists():
            conn.execute(f"""
                CREATE OR REPLACE VIEW raw.taxi_zones AS
                SELECT * FROM read_csv_auto('{zones_file}')
            """)

            result = conn.execute("SELECT COUNT(*) FROM raw.taxi_zones").fetchone()
            row_count = result[0] if result else 0

            print(f"[OK] Created view: raw.taxi_zones")
            print(f"     Taxi zones: {row_count:,} rows")
        else:
            print("[SKIP] taxi_zone_lookup.csv not found")

        print()
        print("=" * 60)
        print("Warehouse setup complete!")
        print("=" * 60)

        # Print summary
        print()
        print("Available tables in 'raw' schema:")
        tables = conn.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'raw'
            ORDER BY table_name
        """).fetchall()

        for table in tables:
            print(f"  - raw.{table[0]}")

    finally:
        conn.close()


def verify_warehouse() -> None:
    """Verify warehouse is set up correctly."""
    if not DB_PATH.exists():
        print("[ERROR] Database does not exist. Run setup first.")
        return

    conn = duckdb.connect(str(DB_PATH), read_only=True)

    try:
        print()
        print("Warehouse verification:")
        print("-" * 40)

        # Check each table
        tables = ["yellow_tripdata", "green_tripdata", "fhv_tripdata", "taxi_zones"]
        for table in tables:
            try:
                result = conn.execute(f"SELECT COUNT(*) FROM raw.{table}").fetchone()
                print(f"  raw.{table}: {result[0]:,} rows")
            except Exception as e:
                print(f"  raw.{table}: [ERROR] {e}")

    finally:
        conn.close()


if __name__ == "__main__":
    setup_warehouse()
    verify_warehouse()
