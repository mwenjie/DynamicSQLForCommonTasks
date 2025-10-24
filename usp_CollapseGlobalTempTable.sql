CREATE OR ALTER PROCEDURE usp_CollapseGlobalTempTable
    @TableName NVARCHAR(128),
    @DateColumn NVARCHAR(128),
    @ValueColumns NVARCHAR(MAX),
    @OtherColumns NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify that the table name is for a global temporary table
    IF LEFT(@TableName, 2) <> N'##'
    BEGIN
        RAISERROR(N'This procedure is designed to work only with global temporary tables (e.g., ##MyTable).', 16, 1);
        RETURN;
    END

    -- Get the object ID for the global temp table from tempdb
    DECLARE @ObjectID INT = OBJECT_ID(N'tempdb..' + @TableName);

    IF @ObjectID IS NULL
    BEGIN
        RAISERROR(N'Global temporary table %s not found.', 16, 1, @TableName);
        RETURN;
    END

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @QuotedValueColumns NVARCHAR(MAX);
    DECLARE @QuotedOtherColumns NVARCHAR(MAX) = N'';
    DECLARE @AllNonDateColumns NVARCHAR(MAX);
    DECLARE @LagComparisons NVARCHAR(MAX);
    DECLARE @OrderByClause NVARCHAR(MAX);
    DECLARE @PartitionByClause NVARCHAR(MAX) = N'1'; -- Default partition if no other columns

    -- Build the list of "Other Columns" if they are provided
    IF @OtherColumns IS NOT NULL AND LTRIM(RTRIM(@OtherColumns)) <> ''
    BEGIN
        SELECT @QuotedOtherColumns = STRING_AGG(QUOTENAME(c.name), ', ')
        FROM tempdb.sys.columns c
        JOIN (SELECT TRIM(value) AS ColumnName FROM STRING_SPLIT(@OtherColumns, ',')) AS v ON c.name = v.ColumnName
        WHERE c.object_id = @ObjectID;
        
        SET @PartitionByClause = @QuotedOtherColumns;
    END

    -- Build the list of "Value Columns" to be checked for changes
    SELECT @QuotedValueColumns = STRING_AGG(QUOTENAME(c.name), ', ')
    FROM tempdb.sys.columns c
    JOIN (SELECT TRIM(value) AS ColumnName FROM STRING_SPLIT(@ValueColumns, ',')) AS v ON c.name = v.ColumnName
    WHERE c.object_id = @ObjectID;

    -- Build the dynamic LAG comparison logic, partitioned by the "Other Columns"
    -- Handle NULL comparisons properly using ISNULL or IS NOT DISTINCT FROM pattern
    SELECT @LagComparisons = STRING_AGG(
        '(LAG(' + QUOTENAME(c.name) + ', 1) OVER (PARTITION BY ' + @PartitionByClause + ' ORDER BY ' + QUOTENAME(@DateColumn) + ') = ' + QUOTENAME(c.name) + 
        ' OR (LAG(' + QUOTENAME(c.name) + ', 1) OVER (PARTITION BY ' + @PartitionByClause + ' ORDER BY ' + QUOTENAME(@DateColumn) + ') IS NULL AND ' + QUOTENAME(c.name) + ' IS NULL))',
        ' AND '
    )
    FROM tempdb.sys.columns c
    JOIN (SELECT TRIM(value) AS ColumnName FROM STRING_SPLIT(@ValueColumns, ',')) AS v ON c.name = v.ColumnName
    WHERE c.object_id = @ObjectID;

    -- Combine all columns for SELECT and GROUP BY
    SET @AllNonDateColumns = CONCAT_WS(', ', NULLIF(@QuotedOtherColumns, ''), @QuotedValueColumns);

    -- Construct the final ORDER BY clause for logical sorting
    SET @OrderByClause = 'ORDER BY ' + ISNULL(@QuotedOtherColumns + ', ', '') + 'SegmentStart';

    -- Build the final dynamic SQL query
    SET @SQL = N'
    WITH ValueChanges AS (
        SELECT
            ' + QUOTENAME(@DateColumn) + ',
            ' + @AllNonDateColumns + ',
            CASE
                WHEN ' + @LagComparisons + ' THEN 0
                ELSE 1
            END AS IsNewGroup
        FROM
            ' + @TableName + '
    ),
    SegmentIdentifier AS (
        SELECT
            *,
            SUM(IsNewGroup) OVER (PARTITION BY ' + @PartitionByClause + ' ORDER BY ' + QUOTENAME(@DateColumn) + ') AS SegmentId
        FROM
            ValueChanges
    )
    SELECT
        MIN(' + QUOTENAME(@DateColumn) + ') AS SegmentStart,
        MAX(' + QUOTENAME(@DateColumn) + ') AS SegmentEnd,
        ' + @AllNonDateColumns + '
    FROM
        SegmentIdentifier
    GROUP BY
        SegmentId,
        ' + @AllNonDateColumns + '
    ' + @OrderByClause;

    -- Execute the final query
    EXEC sp_executesql @SQL;
END
GO