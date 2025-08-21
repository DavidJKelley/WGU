#!/usr/bin/env python3
"""
data_quality_checker.py
Run:  python data_quality_checker.py employee_data.csv
"""

import sys
from pathlib import Path
import re

import pandas as pd
import numpy as np
from textwrap import indent

# -----------------------------------------------------------------------------
EXPECTED_CATEGORIES = {
    "Turnover": {"Yes", "No"},
    "Gender": {"Male", "Female", "Prefer Not to Answer"},
    "MaritalStatus": {"Single", "Married", "Divorced"},
    "CompensationType": {"Salary", "Hourly"},
    "PaycheckMethod": {"Mail Check", "Mailed Check", "Direct_Deposit", "DirectDeposit"},
    "TextMessageOptIn": {"Yes", "No", "N/A"},
}

NUMERIC_COLUMNS = {
    "Age",
    "Tenure",
    "HourlyRate",
    "HoursWeekly",
    "AnnualSalary",
    "DrivingCommuterDistance",
    "NumCompaniesPreviouslyWorked",
    "AnnualProfessionalDevHrs",
}
PRIMARY_KEY = "EmployeeNumber"
REPORT_FILE = "data_quality_report.txt"


# -----------------------------------------------------------------------------
def coerce_numeric_series(s: pd.Series) -> pd.Series:
    """Remove currency symbols/commas, strip whitespace, coerce to float."""
    return (
        s.astype(str)
        .str.replace(r"[^0-9.\-]+", "", regex=True)  # keep digits, dot, minus
        .replace({"": np.nan})
        .astype(float)
    )


def detect_outliers_iqr(series: pd.Series) -> pd.Series:
    """Return boolean mask where True = outlier (IQR rule)."""
    q1 = series.quantile(0.25)
    q3 = series.quantile(0.75)
    iqr = q3 - q1
    lower, upper = q1 - 1.5 * iqr, q3 + 1.5 * iqr
    return (series < lower) | (series > upper)


def tidy_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    # Trim whitespace in all string cells
    str_cols = df.select_dtypes(include="object").columns
    df[str_cols] = df[str_cols].apply(lambda col: col.str.strip())

    # Standardize blank / N/A tokens
    df.replace({"": np.nan, "N/A": np.nan, "n/a": np.nan}, inplace=True)

    # Convert numeric‑like columns
    for col in NUMERIC_COLUMNS & set(df.columns):
        df[col] = coerce_numeric_series(df[col])

    # Harmonize categorical variants (optional – lowercase / underscores)
    df["PaycheckMethod"] = df["PaycheckMethod"].replace(
        {"DirectDeposit": "Direct_Deposit"}
    )

    return df


# -----------------------------------------------------------------------------
def generate_report(df: pd.DataFrame) -> str:
    lines = []

    # 1. Duplicate analysis
    dup_rows = df[df.duplicated()]
    dup_pk = df[df.duplicated(subset=[PRIMARY_KEY])]
    lines += [
        "DUPLICATES",
        f"  Total duplicate rows       : {len(dup_rows)}",
        f"  Duplicate {PRIMARY_KEY}s  : {len(dup_pk)}",
    ]
    if not dup_rows.empty:
        lines.append("  First 5 duplicate rows index numbers:")
        lines.append(indent(", ".join(map(str, dup_rows.index[:5])), "    "))

    # 2. Missing / NaN summary
    na_counts = df.isna().sum()
    lines += ["\nMISSING VALUES"]
    for col, cnt in na_counts.items():
        if cnt:
            lines.append(f"  {col:<30}: {cnt}")

    # 3. Categorical validity
    lines.append("\nINCONSISTENT CATEGORICAL ENTRIES")
    for col, expected in EXPECTED_CATEGORIES.items():
        if col in df.columns:
            bad = set(df[col].dropna().unique()) - expected
            if bad:
                lines.append(f"  {col:<30}: {sorted(bad)}")

    # 4. Formatting red‑flags
    fmt_issues = []
    dollar_cols = [c for c in df.columns if df[c].astype(str).str.contains(r"\$").any()]
    if dollar_cols:
        fmt_issues.append(f"Embedded currency symbols in: {dollar_cols}")
    space_cols = [
        c
        for c in df.columns
        if df[c].dtype == "O" and df[c].str.contains(r"^\s|\s$").any()
    ]
    if space_cols:
        fmt_issues.append(f"Leading/trailing spaces in: {space_cols}")
    lines += ["\nFORMATTING ISSUES"] + (["  " + s for s in fmt_issues] or ["  None"])

    # 5. Outlier detection
    lines.append("\nNUMERIC OUTLIERS (IQR rule)")
    for col in NUMERIC_COLUMNS & set(df.columns):
        s = df[col].dropna()
        outliers = detect_outliers_iqr(s)
        if outliers.any():
            lines.append(f"  {col:<30}: {int(outliers.sum())} outliers")

    return "\n".join(lines)


# -----------------------------------------------------------------------------
def main(csv_path: Path) -> None:
    df = pd.read_csv(csv_path)
    df = tidy_dataframe(df)
    report = generate_report(df)

    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write(f"DATA QUALITY REPORT: {csv_path.name}\n")
        f.write("=" * 60 + "\n\n")
        f.write(report)

    print(f"✔ Report written to {REPORT_FILE}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python data_quality_checker.py <csv_file>")
    main(Path(sys.argv[1]))
