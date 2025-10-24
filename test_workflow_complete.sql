-- =============================================
-- Complete Workflow Test Script
-- This script demonstrates the entire process:
-- 1. Load raw data into ##RawTestData
-- 2. Pivot using usp_CreateDynamicPivotFromTemp to ##PivotedData
-- 3. Collapse using usp_CollapseGlobalTempTable to get final output
-- =============================================

-- Clean up any existing objects
IF OBJECT_ID('tempdb..##RawTestData') IS NOT NULL DROP TABLE ##RawTestData;
IF OBJECT_ID('tempdb..##PivotedData') IS NOT NULL DROP TABLE ##PivotedData;

PRINT '=============================================';
PRINT 'STEP 1: Create and populate raw test data';
PRINT '=============================================';

-- =============================================
-- Create the raw test data table structure
-- =============================================
CREATE TABLE ##RawTestData (
    ContractId INT,
    DateKey DATE,
    Value1 VARCHAR(50),
    Value2 VARCHAR(50),
    Value3 VARCHAR(50),
    RateValue DECIMAL(10, 4),
    VariableValue DECIMAL(10, 4)
);

-- Insert complete test data for Contract 1001 (2023-01-01 to 2023-01-16)
-- This demonstrates multiple rate changes that will create islands
INSERT INTO ##RawTestData (ContractId, DateKey, Value1, Value2, Value3, RateValue, VariableValue)
SELECT * FROM (VALUES
-- Island 1: 2023-01-01 to 2023-01-05 (rates: peak=0.1500, lgc_mandatory=0.0500)
(1001, '2023-01-01', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-01', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-01', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-01', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-01', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-01', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-01', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-02', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-02', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-02', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-02', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-02', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-02', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-02', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-03', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-03', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-03', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-03', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-03', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-03', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-03', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-04', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-04', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-04', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-04', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-04', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-04', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-04', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-05', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-05', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-05', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-05', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-05', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-05', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-05', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

-- Island 2: 2023-01-06 to 2023-01-08 (elec_base_peak changes to 0.1650)
(1001, '2023-01-06', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-06', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-06', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-06', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-06', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-06', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-06', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-07', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-07', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-07', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-07', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-07', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-07', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-07', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-08', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-08', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-08', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-08', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-08', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-08', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-08', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

-- Island 3: 2023-01-09 to 2023-01-14 (lgc_base_mandatory also changes to 0.0550)
(1001, '2023-01-09', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-09', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-09', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-09', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-09', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-09', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-09', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-10', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-10', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-10', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-10', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-10', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-10', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-10', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-11', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-11', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-11', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-11', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-11', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-11', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-11', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-12', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-12', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-12', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-12', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-12', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-12', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-12', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-13', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-13', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-13', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-13', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-13', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-13', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-13', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-14', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-14', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-14', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-14', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-14', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-14', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-14', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

-- Island 4: 2023-01-15 to 2023-01-16 (back to original rates)
(1001, '2023-01-15', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-15', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-15', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-15', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-15', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-15', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-15', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

(1001, '2023-01-16', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-16', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-16', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-16', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-16', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-16', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-16', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

-- Contract 1002 data (two islands)
-- Island 1: 2023-01-17 to 2023-01-22
(1002, '2023-01-17', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-17', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-17', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-17', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-17', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-17', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-17', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-18', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-18', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-18', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-18', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-18', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-18', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-18', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-19', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-19', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-19', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-19', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-19', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-19', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-19', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-20', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-20', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-20', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-20', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-20', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-20', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-20', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-21', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-21', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-21', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-21', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-21', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-21', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-21', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-22', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-22', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-22', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-22', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-22', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-22', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-22', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

-- Island 2 for 1002: 2023-01-23 to 2023-01-30 (lgc_base_mandatory changes to 0.0650)
(1002, '2023-01-23', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-23', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-23', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-23', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-23', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-23', 'lgc', 'base', 'mandatory', 0.0650, 0.0020),
(1002, '2023-01-23', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),

(1002, '2023-01-24', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-24', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-24', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-24', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-24', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-24', 'lgc', 'base', 'mandatory', 0.0650, 0.0020),
(1002, '2023-01-24', 'lgc', 'base', 'voluntary', 0.0400, 0.0015)
) AS DataSource(ContractId, DateKey, Value1, Value2, Value3, RateValue, VariableValue);

PRINT 'Raw test data loaded successfully.';
SELECT 'Raw Data Row Count' AS Info, COUNT(*) AS [Count] FROM ##RawTestData;
PRINT '';

-- =============================================
-- STEP 2: Call the pivot procedure
-- =============================================
PRINT '=============================================';
PRINT 'STEP 2: Pivot the data';
PRINT '=============================================';

EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##RawTestData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##PivotedData';

PRINT '';
SELECT 'Pivoted Data Row Count' AS Info, COUNT(*) AS [Count] FROM ##PivotedData;
PRINT '';
PRINT 'Sample of pivoted data (first 10 rows):';
SELECT TOP 10 * FROM ##PivotedData ORDER BY ContractId, DateKey;
PRINT '';

-- =============================================
-- STEP 3: Call the collapse procedure
-- =============================================
PRINT '=============================================';
PRINT 'STEP 3: Collapse using Gaps and Islands pattern';
PRINT '=============================================';

-- Get the list of rate columns (excluding ContractId and DateKey)
DECLARE @RateColumns NVARCHAR(MAX);
SELECT @RateColumns = STRING_AGG(COLUMN_NAME, ', ')
FROM tempdb.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##PivotedData') AS VARCHAR(100)) + '%'
  AND COLUMN_NAME NOT IN ('ContractId', 'DateKey')
ORDER BY ORDINAL_POSITION;

PRINT 'Rate columns to track for changes: ' + @RateColumns;
PRINT '';

EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##PivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = @RateColumns,
    @OtherColumns = 'ContractId';

PRINT '';
PRINT '=============================================';
PRINT 'Workflow completed successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'Expected output:';
PRINT '- Island 1 (1001): 2023-01-01 to 2023-01-05';
PRINT '- Island 2 (1001): 2023-01-06 to 2023-01-08';
PRINT '- Island 3 (1001): 2023-01-09 to 2023-01-14';
PRINT '- Island 4 (1001): 2023-01-15 to 2023-01-16';
PRINT '- Island 1 (1002): 2023-01-17 to 2023-01-22';
PRINT '- Island 2 (1002): 2023-01-23 to 2023-01-24';

-- Clean up
-- IF OBJECT_ID('tempdb..##RawTestData') IS NOT NULL DROP TABLE ##RawTestData;
-- IF OBJECT_ID('tempdb..##PivotedData') IS NOT NULL DROP TABLE ##PivotedData;
