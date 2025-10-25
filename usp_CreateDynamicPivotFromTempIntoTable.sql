-- Drop the stored procedure if it already exists to start fresh
IF OBJECT_ID('dbo.usp_CreateDynamicPivotFromTempIntoTable', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateDynamicPivotFromTempIntoTable;
GO

CREATE PROCEDURE dbo.usp_CreateDynamicPivotFromTempIntoTable
    -- Parameters to make the pivot reusable and dynamic
    @SourceGlobalTempTableName NVARCHAR(255),   -- The global temp table to pivot (e.g., '##SampleData')
    @TargetGlobalTempTableName NVARCHAR(255),   -- The target global temp table to store results (e.g., '##PivotedData')
    @GroupByColumns NVARCHAR(MAX),              -- Comma-separated list of columns to keep as rows (e.g., 'ContractId,DateKey')
    @CategoryColumns NVARCHAR(MAX),             -- Comma-separated list of columns whose values will form the new column headers (e.g., 'Value1,Value2,Value3')
    @MeasureColumns NVARCHAR(MAX)               -- Comma-separated list of measure columns to be pivoted (e.g., 'Measure1,Measure2,Measure3')
AS
BEGIN
    SET NOCOUNT ON;

    -- ******************** VALIDATION STEP ********************
    -- Verify that the provided source table name is a valid global temporary table that exists.
    IF LEFT(@SourceGlobalTempTableName, 2) <> '##' OR OBJECT_ID(N'tempdb..' + @SourceGlobalTempTableName) IS NULL
    BEGIN
        RAISERROR('Invalid input: The source table name must be an existing global temporary table (e.g., ''##MyTempData'').', 16, 1);
        RETURN;
    END

    -- Verify that the target table name is a valid global temporary table name (but doesn't need to exist yet)
    IF LEFT(@TargetGlobalTempTableName, 2) <> '##'
    BEGIN
        RAISERROR('Invalid input: The target table name must be a global temporary table name (e.g., ''##MyTempData'').', 16, 1);
        RETURN;
    END

    -- Drop the target table if it already exists
    DECLARE @DropTableSql NVARCHAR(MAX);
    IF OBJECT_ID(N'tempdb..' + @TargetGlobalTempTableName) IS NOT NULL
    BEGIN
        SET @DropTableSql = N'DROP TABLE ' + @TargetGlobalTempTableName + ';';
        EXEC sp_executesql @DropTableSql;
    END

    -- ******************** STEP 1: DYNAMIC SQL STRING PREPARATION ********************
    DECLARE @pivotColumns NVARCHAR(MAX);
    DECLARE @pivotColumnConstructor NVARCHAR(MAX);
    DECLARE @unpivotClause NVARCHAR(MAX);
    DECLARE @finalSql NVARCHAR(MAX);

    -- Build the CONCAT expression for creating the new column names from the category columns
    SELECT @pivotColumnConstructor = CONCAT('CONCAT(', STRING_AGG(CONCAT('s.', QUOTENAME(TRIM(value))), ", '_', "), ", '_', m.MeasureName)")
    FROM STRING_SPLIT(@CategoryColumns, ',');

    -- Build the CROSS APPLY clause to unpivot the measure columns
    SELECT @unpivotClause = STRING_AGG(CONCAT("('", TRIM(value), "', s.", QUOTENAME(TRIM(value)), ")"), ', ')
    FROM STRING_SPLIT(@MeasureColumns, ',');

    -- ******************** STEP 2: GENERATE THE PIVOT COLUMN LIST ********************
    -- This query runs against the provided global temp table to discover all unique column combinations.
    DECLARE @columnListSql NVARCHAR(MAX) = N'
        SELECT @result = STRING_AGG(DISTINCT QUOTENAME(PivotColumn), '','')
        FROM (
            SELECT ' + @pivotColumnConstructor + N' AS PivotColumn
            FROM ' + @SourceGlobalTempTableName + N' s
            CROSS APPLY (' + @unpivotClause + N') AS m(MeasureName, MeasureValue)
        ) AS DistinctColumns;';

    EXEC sp_executesql @columnListSql, N'@result NVARCHAR(MAX) OUTPUT', @result = @pivotColumns OUTPUT;

    -- ******************** STEP 3: CONSTRUCT AND EXECUTE THE FINAL PIVOT QUERY ********************
    -- This query creates the target table and populates it with pivoted data
    SET @finalSql = N'
    SELECT
        ' + @GroupByColumns + N',
        ' + @pivotColumns + N'
    INTO ' + @TargetGlobalTempTableName + N'
    FROM
    (
        SELECT
            ' + @GroupByColumns + N',
            m.MeasureValue,
            ' + @pivotColumnConstructor + N' AS PivotColumn
        FROM
            ' + @SourceGlobalTempTableName + N' s
        CROSS APPLY
        (
            ' + @unpivotClause + N'
        ) AS m(MeasureName, MeasureValue)
    ) AS SourceData
    PIVOT
    (
        MAX(MeasureValue)
        FOR PivotColumn IN (' + @pivotColumns + N')
    ) AS PivotedData
    ORDER BY
        ' + @GroupByColumns + N';';

    -- Execute the final, fully constructed dynamic SQL query
    EXEC sp_executesql @finalSql;

    PRINT 'Pivot completed successfully. Results stored in ' + @TargetGlobalTempTableName;
END
GO
