"""
Run the complete NYC Taxi Data Lakehouse pipeline.

Steps:
1. Download raw data (if not present)
2. Set up DuckDB warehouse
3. Install dbt dependencies
4. Run dbt seed (load reference data)
5. Run dbt models
6. Run dbt tests
"""

import subprocess
import sys
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
DBT_PROJECT_DIR = PROJECT_ROOT / "dbt_project"
DATA_DIR = PROJECT_ROOT / "data" / "raw"


def run_command(cmd: list[str], cwd: Path | None = None, description: str = "") -> bool:
    """Run a shell command and return success status."""
    print(f"\n{'=' * 60}")
    print(f"  {description}")
    print(f"{'=' * 60}")
    print(f"  Command: {' '.join(cmd)}")
    print()

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=True,
            text=True,
        )
        print(f"\n  [OK] {description}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n  [FAILED] {description}")
        print(f"  Exit code: {e.returncode}")
        return False


def check_data_exists() -> bool:
    """Check if raw data files exist."""
    parquet_files = list(DATA_DIR.glob("*.parquet"))
    return len(parquet_files) >= 9  # 3 types * 3 months


def main() -> int:
    """Run the complete pipeline."""
    print()
    print("=" * 60)
    print("  NYC TAXI DATA LAKEHOUSE PIPELINE")
    print("=" * 60)
    print()
    print(f"  Project root: {PROJECT_ROOT}")
    print(f"  dbt project:  {DBT_PROJECT_DIR}")
    print()

    steps_completed = 0
    total_steps = 6

    # Step 1: Download data (if needed)
    if not check_data_exists():
        print("  Raw data not found. Downloading...")
        if not run_command(
            [sys.executable, "scripts/download_data.py"],
            cwd=PROJECT_ROOT,
            description="Step 1/6: Download NYC Taxi data",
        ):
            print("\n  Pipeline failed at data download step.")
            return 1
    else:
        print("  [SKIP] Raw data already exists")
    steps_completed += 1

    # Step 2: Setup warehouse
    if not run_command(
        [sys.executable, "scripts/setup_warehouse.py"],
        cwd=PROJECT_ROOT,
        description="Step 2/6: Set up DuckDB warehouse",
    ):
        print("\n  Pipeline failed at warehouse setup step.")
        return 1
    steps_completed += 1

    # Step 3: Install dbt dependencies
    if not run_command(
        ["dbt", "deps"],
        cwd=DBT_PROJECT_DIR,
        description="Step 3/6: Install dbt dependencies",
    ):
        print("\n  Pipeline failed at dbt deps step.")
        return 1
    steps_completed += 1

    # Step 4: Run dbt seed
    if not run_command(
        ["dbt", "seed"],
        cwd=DBT_PROJECT_DIR,
        description="Step 4/6: Load seed data (taxi zones)",
    ):
        print("\n  Pipeline failed at dbt seed step.")
        return 1
    steps_completed += 1

    # Step 5: Run dbt models
    if not run_command(
        ["dbt", "run"],
        cwd=DBT_PROJECT_DIR,
        description="Step 5/6: Run dbt models",
    ):
        print("\n  Pipeline failed at dbt run step.")
        return 1
    steps_completed += 1

    # Step 6: Run dbt tests
    if not run_command(
        ["dbt", "test"],
        cwd=DBT_PROJECT_DIR,
        description="Step 6/6: Run dbt tests",
    ):
        print("\n  Pipeline failed at dbt test step.")
        return 1
    steps_completed += 1

    # Summary
    print()
    print("=" * 60)
    print("  PIPELINE COMPLETE")
    print("=" * 60)
    print()
    print(f"  Steps completed: {steps_completed}/{total_steps}")
    print()
    print("  Next steps:")
    print("    - Generate docs: cd dbt_project && dbt docs generate")
    print("    - Serve docs:    cd dbt_project && dbt docs serve")
    print("    - Query data:    Connect to data/warehouse/lakehouse.duckdb")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
