"""
Download NYC Taxi Trip Data (January - March 2024).

Downloads yellow taxi, green taxi, and FHV trip data in parquet format,
plus the taxi zone lookup CSV.
"""

import asyncio
from pathlib import Path

import httpx
from tqdm import tqdm

# Base URLs for NYC Taxi data
TRIP_DATA_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
MISC_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/misc"

# Data directory
DATA_DIR = Path(__file__).parent.parent / "data" / "raw"

# Months to download (January, February, March 2024)
MONTHS = ["2024-01", "2024-02", "2024-03"]

# Trip types to download
TRIP_TYPES = ["yellow_tripdata", "green_tripdata", "fhv_tripdata"]


def get_download_urls() -> list[dict[str, str]]:
    """Generate list of files to download with their URLs and local paths."""
    downloads = []

    # Trip data files
    for trip_type in TRIP_TYPES:
        for month in MONTHS:
            filename = f"{trip_type}_{month}.parquet"
            downloads.append({
                "url": f"{TRIP_DATA_BASE_URL}/{filename}",
                "path": DATA_DIR / filename,
                "name": filename,
            })

    # Taxi zone lookup
    downloads.append({
        "url": f"{MISC_BASE_URL}/taxi_zone_lookup.csv",
        "path": DATA_DIR / "taxi_zone_lookup.csv",
        "name": "taxi_zone_lookup.csv",
    })

    return downloads


async def download_file(
    client: httpx.AsyncClient,
    url: str,
    path: Path,
    name: str,
    semaphore: asyncio.Semaphore,
) -> None:
    """Download a single file with progress bar."""
    async with semaphore:
        if path.exists():
            print(f"  [SKIP] {name} already exists")
            return

        try:
            async with client.stream("GET", url) as response:
                response.raise_for_status()
                total = int(response.headers.get("content-length", 0))

                with open(path, "wb") as f:
                    with tqdm(
                        total=total,
                        unit="B",
                        unit_scale=True,
                        desc=f"  {name}",
                        leave=True,
                    ) as pbar:
                        async for chunk in response.aiter_bytes(chunk_size=8192):
                            f.write(chunk)
                            pbar.update(len(chunk))

            print(f"  [OK] {name}")

        except httpx.HTTPStatusError as e:
            print(f"  [ERROR] {name}: HTTP {e.response.status_code}")
            if path.exists():
                path.unlink()
        except Exception as e:
            print(f"  [ERROR] {name}: {e}")
            if path.exists():
                path.unlink()


async def main() -> None:
    """Download all NYC Taxi data files."""
    print("=" * 60)
    print("NYC Taxi Data Downloader")
    print("=" * 60)
    print()

    # Ensure data directory exists
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    downloads = get_download_urls()

    print(f"Files to download: {len(downloads)}")
    print(f"Destination: {DATA_DIR}")
    print()

    # Limit concurrent downloads to avoid overwhelming the server
    semaphore = asyncio.Semaphore(3)

    async with httpx.AsyncClient(timeout=httpx.Timeout(300.0)) as client:
        tasks = [
            download_file(client, d["url"], d["path"], d["name"], semaphore)
            for d in downloads
        ]
        await asyncio.gather(*tasks)

    print()
    print("=" * 60)
    print("Download complete!")
    print("=" * 60)

    # Print summary
    files = list(DATA_DIR.glob("*.parquet")) + list(DATA_DIR.glob("*.csv"))
    total_size = sum(f.stat().st_size for f in files if f.exists())
    print(f"Total files: {len(files)}")
    print(f"Total size: {total_size / (1024**3):.2f} GB")


if __name__ == "__main__":
    asyncio.run(main())
