-- =============================================
-- End-to-End Example: Transform Raw Data to Final Output
-- 
-- This script demonstrates the complete workflow described in the problem:
-- 1. Start with raw data (RawTestData.md format)
-- 2. Pivot to create wide format (PivotedTestData.md format)
-- 3. Collapse using gaps and islands pattern (FinalOutputFromRawTestData.md format)
-- =============================================

SET NOCOUNT ON;

-- Clean up any existing objects
IF OBJECT_ID('tempdb..##RawData') IS NOT NULL DROP TABLE ##RawData;
IF OBJECT_ID('tempdb..##PivotedData') IS NOT NULL DROP TABLE ##PivotedData;

PRINT '=============================================';
PRINT 'END-TO-END WORKFLOW DEMONSTRATION';
PRINT '=============================================';
PRINT '';

-- =============================================
-- STEP 1: Load Raw Data
-- =============================================
PRINT 'STEP 1: Loading Raw Test Data';
PRINT '---------------------------------------------';

CREATE TABLE ##RawData (
    ContractId INT NOT NULL,
    DateKey DATE NOT NULL,
    Value1 VARCHAR(50) NOT NULL,
    Value2 VARCHAR(50) NOT NULL,
    Value3 VARCHAR(50) NOT NULL,
    RateValue DECIMAL(10, 4) NULL,
    VariableValue DECIMAL(10, 4) NULL
);

-- Insert comprehensive test data matching the problem statement examples
-- Contract 1001: Multiple rate changes over time
DECLARE @StartDate DATE = '2023-01-01';
DECLARE @Counter INT = 0;

-- Helper variables for rate patterns
WHILE @Counter < 16
BEGIN
    DECLARE @CurrentDate DATE = DATEADD(DAY, @Counter, @StartDate);
    DECLARE @PeakRate DECIMAL(10, 4);
    DECLARE @MandatoryRate DECIMAL(10, 4);
    
    -- Determine rates based on date ranges (creating islands)
    IF @CurrentDate <= '2023-01-05'
    BEGIN
        SET @PeakRate = 0.1500;
        SET @MandatoryRate = 0.0500;
    END
    ELSE IF @CurrentDate <= '2023-01-08'
    BEGIN
        SET @PeakRate = 0.1650;
        SET @MandatoryRate = 0.0500;
    END
    ELSE IF @CurrentDate <= '2023-01-14'
    BEGIN
        SET @PeakRate = 0.1650;
        SET @MandatoryRate = 0.0550;
    END
    ELSE
    BEGIN
        SET @PeakRate = 0.1500;
        SET @MandatoryRate = 0.0500;
    END
    
    -- Insert rows for each rate category
    INSERT INTO ##RawData VALUES
    (1001, @CurrentDate, 'elec', 'base', 'peak', @PeakRate, NULL),
    (1001, @CurrentDate, 'elec', 'base', 'offpeak', 0.0800, NULL),
    (1001, @CurrentDate, 'elec', 'base', 'shoulder', 0.1100, NULL),
    (1001, @CurrentDate, 'elec', 'ums', 'peak', 0.0200, NULL),
    (1001, @CurrentDate, 'elec', 'ums', 'offpeak', 0.0100, NULL),
    (1001, @CurrentDate, 'lgc', 'base', 'mandatory', @MandatoryRate, 0.0010),
    (1001, @CurrentDate, 'lgc', 'base', 'voluntary', 0.0300, 0.0005);
    
    SET @Counter = @Counter + 1;
END

-- Contract 1002: Two distinct rate periods
SET @Counter = 0;
WHILE @Counter < 14
BEGIN
    SET @CurrentDate = DATEADD(DAY, @Counter, '2023-01-17');
    SET @MandatoryRate = CASE WHEN @CurrentDate <= '2023-01-22' THEN 0.0600 ELSE 0.0650 END;
    
    INSERT INTO ##RawData VALUES
    (1002, @CurrentDate, 'elec', 'base', 'peak', 0.1400, NULL),
    (1002, @CurrentDate, 'elec', 'base', 'offpeak', 0.0750, NULL),
    (1002, @CurrentDate, 'elec', 'base', 'shoulder', 0.1000, NULL),
    (1002, @CurrentDate, 'elec', 'ums', 'peak', 0.0250, NULL),
    (1002, @CurrentDate, 'elec', 'ums', 'offpeak', 0.0150, NULL),
    (1002, @CurrentDate, 'lgc', 'base', 'mandatory', @MandatoryRate, 0.0020),
    (1002, @CurrentDate, 'lgc', 'base', 'voluntary', 0.0400, 0.0015);
    
    SET @Counter = @Counter + 1;
END

-- Contract 1003: Two distinct rate periods with shoulder rate change
SET @Counter = 0;
WHILE @Counter < 20
BEGIN
    SET @CurrentDate = DATEADD(DAY, @Counter, '2023-01-31');
    DECLARE @ShoulderRate DECIMAL(10, 4) = CASE WHEN @CurrentDate <= '2023-02-09' THEN 0.1100 ELSE 0.1250 END;
    
    INSERT INTO ##RawData VALUES
    (1003, @CurrentDate, 'elec', 'base', 'peak', 0.1500, NULL),
    (1003, @CurrentDate, 'elec', 'base', 'offpeak', 0.0800, NULL),
    (1003, @CurrentDate, 'elec', 'base', 'shoulder', @ShoulderRate, NULL),
    (1003, @CurrentDate, 'elec', 'ums', 'peak', 0.0200, NULL),
    (1003, @CurrentDate, 'elec', 'ums', 'offpeak', 0.0100, NULL),
    (1003, @CurrentDate, 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
    (1003, @CurrentDate, 'lgc', 'base', 'voluntary', 0.0300, 0.0005);
    
    SET @Counter = @Counter + 1;
END

PRINT 'Raw data loaded successfully.';
PRINT CAST((SELECT COUNT(*) FROM ##RawData) AS VARCHAR(10)) + ' total rows loaded';
PRINT CAST((SELECT COUNT(DISTINCT ContractId) FROM ##RawData) AS VARCHAR(10)) + ' distinct contracts';
PRINT '';

-- Show sample of raw data
PRINT 'Sample Raw Data (first 10 rows for Contract 1001):';
SELECT TOP 10 * FROM ##RawData WHERE ContractId = 1001 ORDER BY DateKey, Value1, Value2, Value3;
PRINT '';

-- =============================================
-- STEP 2: Pivot the Data
-- =============================================
PRINT '=============================================';
PRINT 'STEP 2: Pivoting Data to Wide Format';
PRINT '---------------------------------------------';

EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##RawData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue',
    @OutputTableName = '##PivotedData';

PRINT '';
PRINT CAST((SELECT COUNT(*) FROM ##PivotedData) AS VARCHAR(10)) + ' rows in pivoted data';
PRINT '';

-- Show sample of pivoted data
PRINT 'Sample Pivoted Data (first 10 rows):';
SELECT TOP 10 * FROM ##PivotedData ORDER BY ContractId, DateKey;
PRINT '';

-- =============================================
-- STEP 3: Collapse Using Gaps and Islands Pattern
-- =============================================
PRINT '=============================================';
PRINT 'STEP 3: Collapsing with Gaps and Islands Pattern';
PRINT '---------------------------------------------';

-- Get the list of all rate columns (excluding ContractId and DateKey)
DECLARE @ValueColumns NVARCHAR(MAX);
SELECT @ValueColumns = STRING_AGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ORDINAL_POSITION)
FROM tempdb.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##PivotedData') AS VARCHAR(100)) + '%'
  AND COLUMN_NAME NOT IN ('ContractId', 'DateKey');

PRINT 'Tracking changes in columns: ' + SUBSTRING(@ValueColumns, 1, 100) + '...';
PRINT '';

EXEC dbo.usp_CollapseGlobalTempTable
    @TableName = '##PivotedData',
    @DateColumn = 'DateKey',
    @ValueColumns = @ValueColumns,
    @OtherColumns = 'ContractId';

PRINT '';
PRINT '=============================================';
PRINT 'WORKFLOW COMPLETED SUCCESSFULLY!';
PRINT '=============================================';
PRINT '';
PRINT 'The final output shows date ranges (islands) where all rates remain constant.';
PRINT 'Each row represents a period with no rate changes.';
PRINT '';
PRINT 'Expected Islands:';
PRINT '  Contract 1001:';
PRINT '    - 2023-01-01 to 2023-01-05 (initial rates)';
PRINT '    - 2023-01-06 to 2023-01-08 (peak rate changed to 0.1650)';
PRINT '    - 2023-01-09 to 2023-01-14 (mandatory rate also changed to 0.0550)';
PRINT '    - 2023-01-15 to 2023-01-16 (rates reverted to original)';
PRINT '';
PRINT '  Contract 1002:';
PRINT '    - 2023-01-17 to 2023-01-22 (mandatory rate 0.0600)';
PRINT '    - 2023-01-23 to 2023-01-30 (mandatory rate 0.0650)';
PRINT '';
PRINT '  Contract 1003:';
PRINT '    - 2023-01-31 to 2023-02-09 (shoulder rate 0.1100)';
PRINT '    - 2023-02-10 to 2023-02-19 (shoulder rate 0.1250)';
PRINT '';

-- Clean up (optional - uncomment if you want to remove temp tables)
-- IF OBJECT_ID('tempdb..##RawData') IS NOT NULL DROP TABLE ##RawData;
-- IF OBJECT_ID('tempdb..##PivotedData') IS NOT NULL DROP TABLE ##PivotedData;
