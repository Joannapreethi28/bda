#!/usr/bin/env bash
# usage: ./run.sh sql/file.sql [dry]  -> runs SQL via bq, saves output to results/<name>.txt
S="$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk"
export PATH="$S/bin:$PATH" CLOUDSDK_PYTHON="$S/platform/bundledpython/python.exe"
BQ() { "$CLOUDSDK_PYTHON" "$S/bin/bootstrapping/bq.py" --project_id=faers-sandbox-10151307 --location=US --quiet "$@"; }
f="$1"; name=$(basename "$f" .sql)
if [ "$2" = "dry" ]; then
  BQ query --use_legacy_sql=false --dry_run " $(cat "$f")" 2>&1
else
  BQ query --use_legacy_sql=false --format=pretty --max_rows=200 " $(cat "$f")" 2>&1 | tee "results/$name.txt"
fi
