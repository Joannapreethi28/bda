"""Download a reproducible random sample of openFDA drug/event bulk files.

Picks 25 partition files with random.seed(42) from https://api.fda.gov/download.json
(~297k reports, ~1.2 GB zipped) and downloads them in parallel.

usage: python download_sample.py <out_dir>
"""
import json
import random
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

N_FILES, SEED = 25, 42


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen("https://api.fda.gov/download.json") as r:
        parts = json.load(r)["results"]["drug"]["event"]["partitions"]
    random.seed(SEED)
    sample = random.sample(parts, N_FILES)
    (out / "files.txt").write_text("\n".join(p["file"] for p in sample))

    def fetch(i_url):
        i, url = i_url
        urllib.request.urlretrieve(url, out / f"f{i:02d}.zip")
        print("done", url, flush=True)

    with ThreadPoolExecutor(6) as ex:
        list(ex.map(fetch, enumerate((p["file"] for p in sample), 1)))


if __name__ == "__main__":
    main(sys.argv[1])
