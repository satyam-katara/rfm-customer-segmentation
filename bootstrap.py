"""One-time ETL for #4 RFM Segmentation: xlsx -> retail.db.

The analysis itself is 100% SQL (rfm_segmentation.sql). This script only
does the plumbing: read the UCI Online Retail II workbook, normalise the
dates to ISO, and load both year-sheets into one SQLite table.

Steps:
  1. Download online_retail_II.xlsx from
     https://archive.ics.uci.edu/dataset/502/online+retail+ii
     and drop it in this folder (one click, no login).
  2. pip install pandas openpyxl
  3. python bootstrap.py
  4. sqlite3 retail.db < rfm_segmentation.sql
"""
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
XLSX = HERE / "online_retail_II.xlsx"
DB = HERE / "retail.db"

if not XLSX.exists():
    sys.exit(
        f"[!] {XLSX.name} not found in this folder.\n"
        "    Download it from https://archive.ics.uci.edu/dataset/502/online+retail+ii\n"
        "    (the 'online_retail_II.xlsx' file), place it here, and re-run."
    )

import pandas as pd  # noqa: E402

frames = []
for sheet, df in pd.read_excel(XLSX, sheet_name=None).items():
    df = df.copy()
    # Online Retail II uses spaced/legacy names; normalise to the SQL schema.
    df = df.rename(
        columns={
            "Customer ID": "CustomerID",
            "Invoice": "InvoiceNo",
            "Price": "UnitPrice",
        }
    )
    df["InvoiceDate"] = pd.to_datetime(df["InvoiceDate"]).dt.strftime("%Y-%m-%d")
    frames.append(df)
    print(f"  sheet '{sheet}': {len(df):,} rows")

data = pd.concat(frames, ignore_index=True)

conn = sqlite3.connect(DB)
data.to_sql("retail", conn, if_exists="replace", index=False)
conn.close()

print(f"[ok] {len(data):,} rows -> {DB.name} (table: retail)")
print("[ok] Now run:  sqlite3 retail.db < rfm_segmentation.sql")
