"""Convert downloaded openFDA drug/event zip files into a slim NDJSON file for BigQuery.

The public table bigquery-public-data.fda_drug.drug_event does not exist, so we
upload our own sample. Keeps the original openFDA nested layout (patient.drug,
patient.reaction) but only the fields the plan needs. Leakage fields
(serious, seriousnessother, ..., patientdeath) are deliberately NOT kept.

usage: python prepare_data.py <zip_dir> <out.ndjson.gz>
"""
import gzip
import json
import sys
import zipfile
from pathlib import Path

import ijson

TOP = ["safetyreportid", "receivedate", "seriousnesshospitalization", "seriousnessdeath"]
PAT = ["patientsex", "patientonsetage", "patientonsetageunit"]


def slim(r):
    p = r.get("patient") or {}
    return {
        **{k: r.get(k) for k in TOP},
        "patient": {
            **{k: p.get(k) for k in PAT},
            "drug": [{"medicinalproduct": d.get("medicinalproduct"),
                      "drugcharacterization": d.get("drugcharacterization")}
                     for d in p.get("drug") or []],
            "reaction": [{"reactionmeddrapt": x.get("reactionmeddrapt")}
                         for x in p.get("reaction") or []],
        },
    }


def convert(z):
    """One zip -> list of NDJSON lines (runs in its own process)."""
    lines = []
    with zipfile.ZipFile(z) as zf:
        with zf.open(zf.namelist()[0]) as fi:
            for r in ijson.items(fi, "results.item", use_float=True):
                lines.append(json.dumps(slim(r), default=str))
    return z.name, lines


def main(zip_dir, out):
    from concurrent.futures import ProcessPoolExecutor, as_completed
    zips = sorted(Path(zip_dir).glob("*.zip"))
    n = 0
    with gzip.open(out, "wt", encoding="utf-8") as fo, ProcessPoolExecutor() as ex:
        for fut in as_completed([ex.submit(convert, z) for z in zips]):
            name, lines = fut.result()
            fo.write("\n".join(lines) + "\n")
            n += len(lines)
            print(f"{name}: {len(lines)} reports (running total {n})", flush=True)
    print("TOTAL", n)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
