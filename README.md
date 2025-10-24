# Dynamic SQL for Common Tasks

This repository contains SQL stored procedures for handling common data transformation tasks, specifically:
1. **Dynamic Pivoting**: Transform data from long format to wide format
2. **Gaps and Islands Pattern**: Collapse consecutive rows with identical values into date ranges

## Overview

The complete workflow consists of two main steps:

1. **Pivot**: Transform raw data from long format (with multiple rows per date) into wide format (with one row per date and multiple columns)
2. **Collapse**: Apply the gaps and islands pattern to group consecutive dates with identical values into date ranges

## Stored Procedures

### 1. usp_CreateDynamicPivotFromTemp

This procedure dynamically pivots data from a global temporary table.

**Parameters:**
- `@GlobalTempTableName` (NVARCHAR(255)): Source global temp table name (e.g., '##RawData')
- `@GroupByColumns` (NVARCHAR(MAX)): Comma-separated list of columns to keep as rows (e.g., 'ContractId, DateKey')
- `@CategoryColumns` (NVARCHAR(MAX)): Comma-separated list of columns whose values will form new column headers (e.g., 'Value1, Value2, Value3')
- `@MeasureColumns` (NVARCHAR(MAX)): Comma-separated list of measure columns to be pivoted (e.g., 'RateValue, VariableValue')
- `@OutputTableName` (NVARCHAR(255), Optional): If specified, results will be stored in this global temp table (e.g., '##PivotedData')

**Example:**
```sql
EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##RawTestData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##PivotedData';
```

**What it does:**
- Takes data in long format with multiple rows per date
- Creates column names by concatenating category values with measure names (e.g., 'elec_base_peak_RateValue')
- Pivots the data so each unique combination becomes a column
- Optionally stores results in a new global temp table

### 2. usp_CollapseGlobalTempTable

This procedure implements the gaps and islands pattern to collapse consecutive rows with identical values.

**Parameters:**
- `@TableName` (NVARCHAR(128)): The global temp table to collapse (e.g., '##PivotedData')
- `@DateColumn` (NVARCHAR(128)): Name of the date column to use for ordering
- `@ValueColumns` (NVARCHAR(MAX)): Comma-separated list of columns to check for changes
- `@OtherColumns` (NVARCHAR(MAX), Optional): Comma-separated list of partition columns (e.g., 'ContractId')

**Example:**
```sql
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##PivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = 'elec_base_peak_RateValue, elec_base_offpeak_RateValue, lgc_base_mandatory_RateValue',
    @OtherColumns = 'ContractId';
```

**What it does:**
- Uses LAG() function to detect when any value changes compared to the previous row
- Assigns a segment ID to each group of consecutive rows with identical values
- Collapses each segment into a single row with SegmentStart and SegmentEnd dates
- Partitions by the specified columns (e.g., ContractId) so each contract is processed independently

### Gaps and Islands Pattern Explanation

**Islands**: Contiguous sequences of rows where all rate values are identical. The algorithm finds the start and end of each island.

**Gaps**: Ranges that exist between islands (e.g., missing dates or periods where rates changed).

**How it works:**
1. **LAG()** compares current row to previous row to detect changes
2. **IsNewGroup flag** marks the first row of every island (where values changed)
3. **SUM() OVER()** creates a running total to assign unique SegmentId to all rows in the same island
4. **GROUP BY SegmentId** collapses each island into a single row with MIN(date) and MAX(date)

## Complete Workflow Example

See `test_workflow_complete.sql` for a full working example that:

1. Creates raw test data in long format
2. Pivots it to wide format
3. Collapses consecutive rows using gaps and islands pattern
4. Produces a final output with date ranges for each set of rates

### Expected Input Format (Raw Data)

```
ContractId | DateKey    | Value1 | Value2 | Value3   | RateValue | VariableValue
-----------|------------|--------|--------|----------|-----------|---------------
1001       | 2023-01-05 | elec   | base   | peak     | 0.1500    | NULL
1001       | 2023-01-05 | elec   | base   | offpeak  | 0.0800    | NULL
1001       | 2023-01-05 | lgc    | base   | mandatory| 0.0500    | 0.0010
```

### Intermediate Format (After Pivot)

```
ContractId | DateKey    | elec_base_peak_RateValue | elec_base_offpeak_RateValue | lgc_base_mandatory_RateValue | ...
-----------|------------|--------------------------|-----------------------------|-----------------------------|-----
1001       | 2023-01-01 | 0.1500                   | 0.0800                      | 0.0500                       | ...
1001       | 2023-01-02 | 0.1500                   | 0.0800                      | 0.0500                       | ...
1001       | 2023-01-06 | 0.1650                   | 0.0800                      | 0.0500                       | ...
```

### Final Output Format (After Collapse)

```
SegmentStart | SegmentEnd | ContractId | elec_base_peak_RateValue | elec_base_offpeak_RateValue | ...
-------------|------------|------------|--------------------------|-----------------------------|-
2023-01-01   | 2023-01-05 | 1001       | 0.1500                   | 0.0800                      | ...
2023-01-06   | 2023-01-08 | 1001       | 0.1650                   | 0.0800                      | ...
2023-01-09   | 2023-01-14 | 1001       | 0.1650                   | 0.0800                      | ...
```

## Files in This Repository

- `usp_CreateDynamicPivotFromTemp.sql` - Pivot procedure (enhanced with optional output table)
- `usp_CreateDynamicPivotFromTempIntoTable.sql` - Alternative pivot procedure (always stores to table)
- `usp_CollapseGlobalTempTable.sql` - Gaps and islands collapse procedure
- `test_workflow_complete.sql` - Complete working example with test data
- `RawTestData.md` - Sample raw data format
- `PivotedTestData.md` - Sample pivoted data format
- `FinalOutputFromRawTestData.md` - Expected final output format

## Requirements

- SQL Server 2016 or later (for STRING_SPLIT and STRING_AGG functions)
- Global temporary tables (##TableName) for data passing between procedures

## Usage Notes

1. All procedures work with **global temporary tables** (##TableName) to allow data sharing across sessions
2. The pivot procedure dynamically discovers column names based on actual data values
3. The collapse procedure automatically handles NULL values in comparisons
4. Multiple contracts/entities can be processed together using the @OtherColumns parameter
5. The procedures use dynamic SQL for maximum flexibility

## Testing

Run `test_workflow_complete.sql` to see the complete workflow in action. The script:
- Creates sample data with multiple contracts and rate changes
- Demonstrates the pivot transformation
- Shows the gaps and islands collapse
- Validates the expected output format
