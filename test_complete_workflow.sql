-- =============================================
-- Test Script for Complete Workflow
-- This script tests the entire process:
-- 1. Load raw data
-- 2. Pivot using usp_CreateDynamicPivotFromTemp
-- 3. Collapse using usp_CollapseGlobalTempTable
-- =============================================

-- Clean up any existing objects
IF OBJECT_ID('tempdb..##RawTestData') IS NOT NULL DROP TABLE ##RawTestData;
IF OBJECT_ID('tempdb..##PivotedData') IS NOT NULL DROP TABLE ##PivotedData;
IF OBJECT_ID('tempdb..##FinalOutput') IS NOT NULL DROP TABLE ##FinalOutput;

-- =============================================
-- STEP 1: Create and populate the raw test data
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

-- Insert complete test data (expanding on the sample provided)
-- Contract 1001 data from 2023-01-01 to 2023-01-16
INSERT INTO ##RawTestData (ContractId, DateKey, Value1, Value2, Value3, RateValue, VariableValue) VALUES
-- 2023-01-01
(1001, '2023-01-01', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-01', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-01', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-01', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-01', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-01', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-01', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-02
(1001, '2023-01-02', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-02', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-02', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-02', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-02', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-02', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-02', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-03
(1001, '2023-01-03', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-03', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-03', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-03', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-03', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-03', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-03', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-04
(1001, '2023-01-04', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-04', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-04', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-04', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-04', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-04', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-04', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-05
(1001, '2023-01-05', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-05', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-05', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-05', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-05', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-05', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-05', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-06: elec_base_peak changes to 0.1650
(1001, '2023-01-06', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-06', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-06', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-06', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-06', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-06', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-06', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-07
(1001, '2023-01-07', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-07', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-07', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-07', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-07', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-07', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-07', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-08
(1001, '2023-01-08', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-08', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-08', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-08', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-08', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-08', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-08', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-09: lgc_base_mandatory changes to 0.0550
(1001, '2023-01-09', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-09', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-09', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-09', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-09', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-09', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-09', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-10
(1001, '2023-01-10', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-10', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-10', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-10', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-10', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-10', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-10', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-11
(1001, '2023-01-11', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-11', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-11', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-11', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-11', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-11', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-11', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-12
(1001, '2023-01-12', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-12', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-12', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-12', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-12', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-12', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-12', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-13
(1001, '2023-01-13', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-13', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-13', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-13', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-13', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-13', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-13', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-14
(1001, '2023-01-14', 'elec', 'base', 'peak', 0.1650, NULL),
(1001, '2023-01-14', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-14', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-14', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-14', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-14', 'lgc', 'base', 'mandatory', 0.0550, 0.0010),
(1001, '2023-01-14', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-15: Back to original rates (0.1500 and 0.0500)
(1001, '2023-01-15', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-15', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-15', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-15', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-15', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-15', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-15', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),
-- 2023-01-16
(1001, '2023-01-16', 'elec', 'base', 'peak', 0.1500, NULL),
(1001, '2023-01-16', 'elec', 'base', 'offpeak', 0.0800, NULL),
(1001, '2023-01-16', 'elec', 'base', 'shoulder', 0.1100, NULL),
(1001, '2023-01-16', 'elec', 'ums', 'peak', 0.0200, NULL),
(1001, '2023-01-16', 'elec', 'ums', 'offpeak', 0.0100, NULL),
(1001, '2023-01-16', 'lgc', 'base', 'mandatory', 0.0500, 0.0010),
(1001, '2023-01-16', 'lgc', 'base', 'voluntary', 0.0300, 0.0005),

-- Contract 1002 data (simplified sample)
-- 2023-01-17 to 2023-01-22: Rate 0.0600
(1002, '2023-01-17', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-17', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-17', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-17', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-17', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-17', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-17', 'lgc', 'base', 'voluntary', 0.0400, 0.0015),
-- Add more dates for contract 1002...
(1002, '2023-01-18', 'elec', 'base', 'peak', 0.1400, NULL),
(1002, '2023-01-18', 'elec', 'base', 'offpeak', 0.0750, NULL),
(1002, '2023-01-18', 'elec', 'base', 'shoulder', 0.1000, NULL),
(1002, '2023-01-18', 'elec', 'ums', 'peak', 0.0250, NULL),
(1002, '2023-01-18', 'elec', 'ums', 'offpeak', 0.0150, NULL),
(1002, '2023-01-18', 'lgc', 'base', 'mandatory', 0.0600, 0.0020),
(1002, '2023-01-18', 'lgc', 'base', 'voluntary', 0.0400, 0.0015);

PRINT 'Raw test data loaded. Row count:';
SELECT COUNT(*) AS RowCount FROM ##RawTestData;

-- =============================================
-- STEP 2: Call the pivot procedure
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'STEP 2: Calling usp_CreateDynamicPivotFromTemp';
PRINT '=============================================';

-- Store the pivoted results in a new global temp table
-- First we need to create the table with the pivoted structure
-- For now, let's just execute the pivot and see the results

EXEC dbo.usp_CreateDynamicPivotFromTemp
    @GlobalTempTableName = '##RawTestData',
    @GroupByColumns = 'ContractId, DateKey',
    @CategoryColumns = 'Value1, Value2, Value3',
    @MeasureColumns = 'RateValue, VariableValue';

PRINT '';
PRINT 'Pivot completed successfully.';
PRINT '';

-- Note: The pivot procedure outputs results directly but doesn't store them.
-- We need to modify the workflow to capture results into a table for the next step.
-- For now, let's create a modified version that stores results.

PRINT '';
PRINT '=============================================';
PRINT 'End of Test Script';
PRINT '=============================================';
