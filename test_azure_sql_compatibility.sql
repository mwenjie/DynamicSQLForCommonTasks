-- =============================================
-- Azure SQL Compatibility Test
-- This script tests the fixed CROSS APPLY VALUES syntax
-- =============================================

PRINT '=============================================';
PRINT 'Testing Azure SQL Compatibility Fix';
PRINT '=============================================';
PRINT '';

-- Clean up
IF OBJECT_ID('tempdb..##TestAzureRaw') IS NOT NULL DROP TABLE ##TestAzureRaw;
IF OBJECT_ID('tempdb..##TestAzurePivoted') IS NOT NULL DROP TABLE ##TestAzurePivoted;

PRINT 'Step 1: Creating test data with multiple measures...';
PRINT '';

-- Create minimal test data to verify the unpivot logic
CREATE TABLE ##TestAzureRaw (
    ContractId INT,
    DateKey DATE,
    Value1 VARCHAR(50),
    Value2 VARCHAR(50),
    Value3 VARCHAR(50),
    RateValue DECIMAL(10, 4),
    VariableValue DECIMAL(10, 4)
);

-- Insert test data
INSERT INTO ##TestAzureRaw VALUES
(1001, '2023-01-01', 'elec', 'base', 'peak', 0.1500, 0.0010),
(1001, '2023-01-01', 'lgc', 'base', 'mandatory', 0.0500, 0.0020),
(1001, '2023-01-02', 'elec', 'base', 'peak', 0.1600, 0.0015),
(1001, '2023-01-02', 'lgc', 'base', 'mandatory', 0.0550, 0.0025);

SELECT 'Input Data' AS Step, * FROM ##TestAzureRaw ORDER BY ContractId, DateKey, Value1;

PRINT '';
PRINT 'Step 2: Testing pivot procedure with VALUES syntax...';
PRINT '';

-- Test the pivot procedure
BEGIN TRY
    EXEC dbo.usp_CreateDynamicPivotFromTemp
        @GlobalTempTableName = '##TestAzureRaw',
        @GroupByColumns = 'ContractId, DateKey',
        @CategoryColumns = 'Value1, Value2, Value3',
        @MeasureColumns = 'RateValue, VariableValue',
        @OutputTableName = '##TestAzurePivoted';
    
    PRINT '';
    PRINT 'SUCCESS: Pivot procedure executed without errors!';
    PRINT '';
    
    SELECT 'Pivoted Output' AS Step, * FROM ##TestAzurePivoted ORDER BY ContractId, DateKey;
    
    PRINT '';
    PRINT 'Step 3: Verifying output structure...';
    
    -- Verify the expected columns were created
    DECLARE @colCount INT;
    SELECT @colCount = COUNT(*)
    FROM tempdb.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##TestAzurePivoted') AS VARCHAR(100)) + '%';
    
    PRINT 'Total columns in pivoted table: ' + CAST(@colCount AS VARCHAR(10));
    
    -- List the columns
    PRINT 'Columns created:';
    SELECT COLUMN_NAME, DATA_TYPE
    FROM tempdb.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME LIKE '%' + CAST(OBJECT_ID('tempdb..##TestAzurePivoted') AS VARCHAR(100)) + '%'
    ORDER BY ORDINAL_POSITION;
    
    PRINT '';
    PRINT '=============================================';
    PRINT 'TEST PASSED: Azure SQL compatibility verified!';
    PRINT '=============================================';
    
END TRY
BEGIN CATCH
    PRINT '';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    PRINT 'Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
    PRINT '';
    PRINT '=============================================';
    PRINT 'TEST FAILED';
    PRINT '=============================================';
END CATCH

-- Clean up
IF OBJECT_ID('tempdb..##TestAzureRaw') IS NOT NULL DROP TABLE ##TestAzureRaw;
IF OBJECT_ID('tempdb..##TestAzurePivoted') IS NOT NULL DROP TABLE ##TestAzurePivoted;
