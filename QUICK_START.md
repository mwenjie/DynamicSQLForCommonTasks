# Quick Start Guide

## How to Use These Procedures

### Step 1: Create the Stored Procedures

Run these SQL files in your SQL Server database to create the procedures:

```sql
-- Run these files in order:
-- 1. Create the pivot procedure (choose one)
-- usp_CreateDynamicPivotFromTemp.sql        -- Enhanced version with optional output
-- OR
-- usp_CreateDynamicPivotFromTempIntoTable.sql  -- Alternative that always outputs to table

-- 2. Create the collapse procedure
-- usp_CollapseGlobalTempTable.sql
```

### Step 2: Prepare Your Raw Data

Your raw data should be in a **global temporary table** (starts with ##) in long format:

```sql
CREATE TABLE ##MyRawData (
    ContractId INT,
    DateKey DATE,
    Value1 VARCHAR(50),      -- Category column 1 (e.g., 'elec', 'lgc')
    Value2 VARCHAR(50),      -- Category column 2 (e.g., 'base', 'ums')
    Value3 VARCHAR(50),      -- Category column 3 (e.g., 'peak', 'offpeak')
    RateValue DECIMAL(10,4), -- Measure to pivot
    VariableValue DECIMAL(10,4) -- Another measure to pivot
);

-- Insert your data...
```

### Step 3: Pivot the Data

```sql
-- Option A: Output to a new table
EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##MyRawData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##MyPivotedData';

-- Option B: Just return results (no table creation)
EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##MyRawData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue';
```

**Result**: Data is now in wide format with columns like `elec_base_peak_RateValue`, `lgc_base_mandatory_VariableValue`, etc.

### Step 4: Collapse Using Gaps and Islands

First, get the list of rate columns to track:

```sql
-- Get all columns except ContractId and DateKey
DECLARE @RateColumns NVARCHAR(MAX);
SELECT @RateColumns = STRING_AGG(COLUMN_NAME, ', ')
FROM tempdb.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##MyPivotedData') AS VARCHAR(100)) + '%'
  AND COLUMN_NAME NOT IN ('ContractId', 'DateKey')
ORDER BY ORDINAL_POSITION;
```

Then collapse the data:

```sql
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##MyPivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = @RateColumns,
    @OtherColumns = 'ContractId';  -- Partition by ContractId
```

**Result**: Data is collapsed into date ranges where all rates are constant.

## Complete Example

```sql
-- 1. Create raw data
CREATE TABLE ##MyRawData (
    ContractId INT,
    DateKey DATE,
    Value1 VARCHAR(50),
    Value2 VARCHAR(50),
    Value3 VARCHAR(50),
    RateValue DECIMAL(10,4),
    VariableValue DECIMAL(10,4)
);

INSERT INTO ##MyRawData VALUES
(1001, '2023-01-01', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-02', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-03', 'elec', 'base', 'peak', 0.1650, NULL);

-- 2. Pivot
EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##MyRawData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##MyPivotedData';

-- 3. Get rate columns
DECLARE @RateColumns NVARCHAR(MAX);
SELECT @RateColumns = STRING_AGG(COLUMN_NAME, ', ')
FROM tempdb.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##MyPivotedData') AS VARCHAR(100)) + '%'
  AND COLUMN_NAME NOT IN ('ContractId', 'DateKey');

-- 4. Collapse
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##MyPivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = @RateColumns,
    @OtherColumns = 'ContractId';
```

**Output**:
```
SegmentStart | SegmentEnd | ContractId | elec_base_peak_RateValue | ...
2023-01-01   | 2023-01-02 | 1001       | 0.1500                   | ...
2023-01-03   | 2023-01-03 | 1001       | 0.1650                   | ...
```

## Testing Your Implementation

Run the provided test scripts to verify everything works:

1. **Quick test**: `test_simple.sql`
2. **Full demo**: `demo_end_to_end.sql`
3. **Comprehensive test**: `test_workflow_complete.sql`

## Common Issues and Solutions

### Issue: "Invalid input: The table name must be an existing global temporary table"
**Solution**: Make sure your table name starts with `##` and the table exists before calling the procedure.

### Issue: Column names have spaces or special characters
**Solution**: The procedures handle this automatically by using QUOTENAME and TRIM.

### Issue: NULL values causing incorrect islands
**Solution**: This is fixed in the enhanced version. Make sure you're using the updated `usp_CollapseGlobalTempTable.sql`.

### Issue: Too many columns in pivot output
**Solution**: Consider filtering your category columns or measure columns to only include what you need.

## Advanced Usage

### Multiple Partition Columns
```sql
-- Collapse by Contract AND Region
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##MyPivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = @RateColumns,
    @OtherColumns = 'ContractId, RegionId';
```

### Selective Value Tracking
```sql
-- Only track specific columns for changes
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##MyPivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = 'elec_base_peak_RateValue, lgc_base_mandatory_RateValue',
    @OtherColumns = 'ContractId';
```

### Different Date Columns
```sql
-- Use a different date column name
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##MyPivotedData',
    @DateColumn = 'EffectiveDate',
    @ValueColumns = @RateColumns,
    @OtherColumns = 'ContractId';
```

## Parameter Reference

### usp_CreateDynamicPivotFromTemp

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| @GlobalTempTableName | NVARCHAR(255) | Yes | Source table name (must start with ##) |
| @GroupByColumns | NVARCHAR(MAX) | Yes | Columns to keep as rows (comma-separated) |
| @CategoryColumns | NVARCHAR(MAX) | Yes | Columns that form new column names (comma-separated) |
| @MeasureColumns | NVARCHAR(MAX) | Yes | Columns to pivot (comma-separated) |
| @OutputTableName | NVARCHAR(255) | No | Target table to create (must start with ##) |

### usp_CollapseGlobalTempTable

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| @TableName | NVARCHAR(128) | Yes | Table to collapse (must start with ##) |
| @DateColumn | NVARCHAR(128) | Yes | Date column name for ordering |
| @ValueColumns | NVARCHAR(MAX) | Yes | Columns to check for changes (comma-separated) |
| @OtherColumns | NVARCHAR(MAX) | No | Partition columns (comma-separated) |

## Need Help?

- Review the sample data files: `RawTestData.md`, `PivotedTestData.md`, `FinalOutputFromRawTestData.md`
- Check the implementation summary: `IMPLEMENTATION_SUMMARY.md`
- Read the full documentation: `README.md`
