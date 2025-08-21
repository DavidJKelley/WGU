#!/usr/bin/env python3
"""
employee_data_cleaner.py
Usage:
    python employee_data_cleaner.py Employee_Turnover_Dataset.csv
Produces:
    employee_data_cleaned.csv   – fully corrected data
    employee_data_issues.csv    – log of each fix / flag
"""

import sys
from pathlib import Path
import numpy as np
import pandas as pd

# note upcoming release changes... 

# --------------------------- configurable “rules” -----------------------------

PRIMARY_KEY = "EmployeeNumber"

EXPECTED_CATEGORIES = {
    "Turnover": {"Yes", "No"},
    "Gender": {"Male", "Female", "Prefer Not to Answer"},
    "MaritalStatus": {"Single", "Married", "Divorced"},
    "CompensationType": {"Salary", "Hourly"},
    "PaycheckMethod": {"Mail Check", "Mailed Check", "Direct_Deposit"},
    "TextMessageOptIn": {"Yes", "No"},
}

CATEGORY_FIXUPS = {
    "PaycheckMethod": {
        "DirectDeposit": "Direct_Deposit",
        "Mail_Check": "Mail Check",
        "MailedCheck": "Mailed Check",
        "Direct Deposit": "Direct_Deposit",
    }
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

MISSING_DEFAULTS = {
    "TextMessageOptIn": "No",
    "NumCompaniesPreviouslyWorked": 0,
    "AnnualProfessionalDevHrs": 0,
}

# winsorisation limits for outliers (IQR cap)
WINSOR_FACTOR = 1.5

# -----------------------------------------------------------------------------


def clean_numeric(col: pd.Series) -> pd.Series:
    """Strip $/commas, coerce to float."""
    cleaned = (
        col.astype(str)
        .str.replace(r"[^0-9.\-]+", "", regex=True)
        .replace({"": np.nan})
        .astype(float)
    )
    return cleaned


def winsorize(series: pd.Series, factor: float = 1.5) -> pd.Series:
    """Cap outliers using the IQR rule (two‑sided winsorisation)."""
    q1, q3 = series.quantile([0.25, 0.75])
    iqr = q3 - q1
    lower, upper = q1 - factor * iqr, q3 + factor * iqr
    return series.clip(lower, upper)


def tidy(df: pd.DataFrame) -> tuple[pd.DataFrame, list[dict]]:
    """
    Clean the dataframe and collect an issue‑log (list of dicts).
    Each dict later becomes one row in employee_data_issues.csv.
    """
    issues: list[dict] = []

    # ------------------------------------------------------------------ trim / blank handling
    obj_cols = df.select_dtypes(include="object").columns
    df[obj_cols] = df[obj_cols].apply(lambda c: c.str.strip() if c.dtype == "object" else c)
    df.replace({"": np.nan, "N/A": np.nan, "n/a": np.nan}, inplace=True)

    # ------------------------------------------------------------------ duplicates
    dupe_mask = df.duplicated(subset=[PRIMARY_KEY], keep="first")
    for idx in df.index[dupe_mask]:
        issues.append(
            {"Row": idx, "Column": PRIMARY_KEY, "Issue": "Duplicate PK", "Original": df.loc[idx, PRIMARY_KEY], "Fixed": "ROW_REMOVED"}
        )
    df = df[~dupe_mask]  # drop duplicates entirely

    # ------------------------------------------------------------------ numeric cleaning & outlier capping
    for col in NUMERIC_COLUMNS & set(df.columns):
        # detect embedded currency symbols BEFORE cleaning
        bad_currency = df[col].astype(str).str.contains(r"\$")
        for idx in df.index[bad_currency]:
            issues.append({"Row": idx, "Column": col, "Issue": "Removed $ symbol", "Original": df.at[idx, col], "Fixed": None})
        df[col] = clean_numeric(df[col])

        # fill missing numeric with column median (after cleaning but before winsor)
        if df[col].isna().any():
            median_val = df[col].median()
            for idx in df[df[col].isna()].index:
                issues.append({"Row": idx, "Column": col, "Issue": "Missing numeric filled", "Original": np.nan, "Fixed": median_val})
            df[col].fillna(median_val, inplace=True)

        # winsorise for outliers
        before = df[col].copy()
        df[col] = winsorize(df[col], WINSOR_FACTOR)
        changed = before != df[col]
        for idx in df.index[changed]:
            issues.append({"Row": idx, "Column": col, "Issue": "Outlier capped (winsor)", "Original": before.at[idx], "Fixed": df.at[idx, col]})

    # ------------------------------------------------------------------ categorical harmonisation
    for col, mapping in CATEGORY_FIXUPS.items():
        if col not in df.columns:
            continue
        for wrong_val, right_val in mapping.items():
            mask = df[col] == wrong_val
            for idx in df.index[mask]:
                issues.append({"Row": idx, "Column": col, "Issue": "Category normalised", "Original": wrong_val, "Fixed": right_val})
        df[col].replace(mapping, inplace=True)

    # ------------------------------------------------------------------ validate expected categories
    for col, allowed in EXPECTED_CATEGORIES.items():
        if col not in df.columns:
            continue
        bad_vals = set(df[col].dropna()) - allowed
        for bad in bad_vals:
            mask = df[col] == bad
            for idx in df.index[mask]:
                issues.append({"Row": idx, "Column": col, "Issue": "Unexpected category", "Original": bad, "Fixed": None})

    # ------------------------------------------------------------------ fill specified missing values
    for col, default in MISSING_DEFAULTS.items():
        if col not in df.columns:
            continue
        missing_mask = df[col].isna()
        for idx in df.index[missing_mask]:
            issues.append({"Row": idx, "Column": col, "Issue": "Missing filled", "Original": np.nan, "Fixed": default})
        df[col].fillna(default, inplace=True)

    return df, issues


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python employee_data_cleaner.py <csv_file>")

    in_path = Path(sys.argv[1])
    if not in_path.exists():
        sys.exit(f"File not found: {in_path}")

    df_raw = pd.read_csv(in_path)
    df_clean, issue_log = tidy(df_raw)

    # ---------------------- output files -------------------------------------
    cleaned_path = in_path.with_name("employee_data_cleaned.csv")
    df_clean.to_csv(cleaned_path, index=False)

    issues_df = pd.DataFrame(issue_log)
    issues_path = in_path.with_name("employee_data_issues.csv")
    issues_df.to_csv(issues_path, index=False)

    print("✔ Cleaning complete")
    print(f"   Cleaned data  ➜  {cleaned_path.name}")
    print(f"   Issues log    ➜  {issues_path.name}")
    print(f"   Rows removed (duplicates): {sum(df_raw.duplicated(subset=[PRIMARY_KEY]))}")
    print(f"   Total issues recorded     : {len(issue_log)}")


if __name__ == "__main__":
    main()
