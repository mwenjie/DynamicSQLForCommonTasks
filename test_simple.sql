-- =============================================
-- Simple Test Script for Basic Validation
-- This script tests the procedures with minimal data
-- =============================================

-- Clean up
IF OBJECT_ID('tempdb..##TestRaw') IS NOT NULL DROP TABLE ##TestRaw;
IF OBJECT_ID('tempdb..##TestPivoted') IS NOT NULL DROP TABLE ##TestPivoted;

PRINT '=== Creating Simple Test Data ===';

-- Create minimal test data
CREATE TABLE ##TestRaw (
    ContractId INT,
    DateKey DATE,
    Value1 VARCHAR(50),
    Value2 VARCHAR(50),
    Value3 VARCHAR(50),
    RateValue DECIMAL(10, 4),
    VariableValue DECIMAL(10, 4)
);

-- Insert simple test data with clear pattern
INSERT INTO ##TestRaw VALUES
-- Day 1 and 2: Same rates
(1001, '2023-01-01', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-01', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-02', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-02', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
-- Day 3: Rate change
(1001, '2023-01-03', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-03', 'lgc', 'base', 'mandatory', 0.0500, 0.0010);

SELECT 'Raw Data' AS Step, * FROM ##TestRaw ORDER BY DateKey, Value1;

PRINT '';
PRINT '=== Testing Pivot Procedure ===';

-- Test pivot
EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##TestRaw',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##TestPivoted';

PRINT '';
SELECT 'Pivoted Data' AS Step, * FROM ##TestPivoted ORDER BY DateKey;

PRINT '';
PRINT '=== Testing Collapse Procedure ===';

-- Get dynamic column list
DECLARE @cols NVARCHAR(MAX);
SELECT @cols = STRING_AGG(COLUMN_NAME, ', ')
FROM tempdb.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##TestPivoted') AS VARCHAR(100)) + '%'
  AND COLUMN_NAME NOT IN ('ContractId', 'DateKey');

-- Test collapse
EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##TestPivoted',
    @DateColumn = 'DateKey',
    @ValueColumns = @cols,
    @OtherColumns = 'ContractId';

PRINT '';
PRINT '=== Test Complete ===';
PRINT 'Expected: Two segments (2023-01-01 to 2023-01-02, and 2023-01-03 to 2023-01-03)';
