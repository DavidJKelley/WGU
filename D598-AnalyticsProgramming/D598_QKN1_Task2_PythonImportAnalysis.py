import pandas as pd
import numpy as np

# 1. Load CSV into DataFrame
data = pd.read_csv("D598 Data Set.csv")

# 2. Remove exact duplicates
data.drop_duplicates(inplace=True)

# 3. Rename columns to clean and standard format (optional, for easier coding)
data.columns = [col.strip().replace(" ", "_") for col in data.columns]

# 4. Ensure numeric columns are parsed correctly (may not be needed, but safe)
numeric_cols = data.select_dtypes(include=["number"]).columns

# 5. Group by Business_State and calculate mean, median, min, max for all numeric columns
agg_funcs = {}
for col in numeric_cols:
    agg_funcs[f"{col}_Mean"] = (col, "mean")
    agg_funcs[f"{col}_Median"] = (col, "median")
    agg_funcs[f"{col}_Min"] = (col, "min")
    agg_funcs[f"{col}_Max"] = (col, "max")

grouped_stats = data.groupby("Business_State").agg(**agg_funcs).reset_index()

# 6. Filter businesses with negative Debt-to-Equity ratio
negative_debt_equity = data[data["Debt_to_Equity"] < 0]

# 7. Add DebtToIncome column
data["DebtToIncome"] = data.apply(
    lambda row: row["Total_Long-term_Debt"] / row["Total_Revenue"] if row["Total_Revenue"] != 0 else np.nan,
    axis=1
)

# 8. Final DataFrame (with DebtToIncome)
final_result = data.copy()

# 9. write out file
final_result.to_csv("final_data_with_dti.csv", index=False)

