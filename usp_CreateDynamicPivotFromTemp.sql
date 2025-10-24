-- Drop the stored procedure if it already exists to start fresh
IF OBJECT_ID('dbo.usp_CreateDynamicPivotFromTemp', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateDynamicPivotFromTemp;
GO

CREATE PROCEDURE dbo.usp_CreateDynamicPivotFromTemp
    -- Parameters to make the pivot reusable and dynamic
    @GlobalTempTableName NVARCHAR(255),   -- The global temp table to pivot (e.g., '##SampleData')
    @GroupByColumns NVARCHAR(MAX),      -- Comma-separated list of columns to keep as rows (e.g., 'ContractId,DateKey')
    @CategoryColumns NVARCHAR(MAX),     -- Comma-separated list of columns whose values will form the new column headers (e.g., 'Value1,Value2,Value3')
    @MeasureColumns NVARCHAR(MAX)       -- Comma-separated list of measure columns to be pivoted (e.g., 'Measure1,Measure2,Measure3')
AS
BEGIN
    SET NOCOUNT ON;

    -- ******************** VALIDATION STEP ********************
    -- Verify that the provided table name is a valid global temporary table that exists.
    IF LEFT(@GlobalTempTableName, 2) <> '##' OR OBJECT_ID(N'tempdb..' + @GlobalTempTableName) IS NULL
    BEGIN
        RAISERROR('Invalid input: The table name must be an existing global temporary table (e.g., ''##MyTempData'').', 16, 1);
        RETURN;
    END

    -- ******************** STEP 1: DYNAMIC SQL STRING PREPARATION ********************
    DECLARE @pivotColumns NVARCHAR(MAX);
    DECLARE @pivotColumnConstructor NVARCHAR(MAX);
    DECLARE @unpivotClause NVARCHAR(MAX);
    DECLARE @finalSql NVARCHAR(MAX);

    -- Build the CONCAT expression for creating the new column names from the category columns
    SELECT @pivotColumnConstructor = CONCAT('CONCAT(', STRING_AGG(CONCAT('s.', QUOTENAME(value)), ", '_', "), ", '_', m.MeasureName)")
    FROM STRING_SPLIT(@CategoryColumns, ',');

    -- Build the CROSS APPLY clause to unpivot the measure columns
    SELECT @unpivotClause = STRING_AGG(CONCAT("('", value, "', s.", QUOTENAME(value), ")"), ', ')
    FROM STRING_SPLIT(@MeasureColumns, ',');

    -- ******************** STEP 2: GENERATE THE PIVOT COLUMN LIST ********************
    -- This query runs against the provided global temp table to discover all unique column combinations.
    DECLARE @columnListSql NVARCHAR(MAX) = N'
        SELECT @result = STRING_AGG(DISTINCT QUOTENAME(PivotColumn), '','')
        FROM (
            SELECT ' + @pivotColumnConstructor + N' AS PivotColumn
            FROM ' + @GlobalTempTableName + N' s
            CROSS APPLY (' + @unpivotClause + N') AS m(MeasureName, MeasureValue)
        ) AS DistinctColumns;';

    EXEC sp_executesql @columnListSql, N'@result NVARCHAR(MAX) OUTPUT', @result = @pivotColumns OUTPUT;

    -- ******************** STEP 3: CONSTRUCT AND EXECUTE THE FINAL PIVOT QUERY ********************
    -- This query is also built to run against the provided global temp table.
    SET @finalSql = N'
    SELECT
        ' + @GroupByColumns + N',
        ' + @pivotColumns + N'
    FROM
    (
        SELECT
            ' + @GroupByColumns + N',
            m.MeasureValue,
            ' + @pivotColumnConstructor + N' AS PivotColumn
        FROM
            ' + @GlobalTempTableName + N' s
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

END
GO