-- =============================================================================
-- Script   : proc_load_bronze.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script creates a stored procedure called 'bronze.load_bronze'.
--     Its job is to load raw data from CSV files into the six bronze tables.
--
--     For each table, it does two things:
--       1. Clears the table (TRUNCATE) to remove any previously loaded data
--       2. Loads fresh data from the CSV file (BULK INSERT)
--
--     This is called a "Full Load" pattern — we reload everything from scratch
--     every time instead of only loading new records. This keeps it simple and
--     ensures the bronze layer always mirrors the source files exactly.
--
-- How to Run:
--     EXEC bronze.load_bronze;
--
-- Parameters:
--     None. This procedure takes no inputs and returns no values.
--
-- ⚠ Before Running:
--     Update the file paths in each BULK INSERT block to match the location
--     of your CSV files on your local machine.
--     Example: Change 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets...' to your actual path.
--
-- Execution Order:
--     Run this AFTER ddl_bronze.sql (tables must exist before loading data).
-- =============================================================================


CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

    -- Variables to track how long each table load takes
    -- @start_time / @end_time    → tracks one table at a time
    -- @batch_start_time / @batch_end_time → tracks the entire procedure run
    DECLARE @start_time       DATETIME,
            @end_time         DATETIME,
            @batch_start_time DATETIME,
            @batch_end_time   DATETIME;

    BEGIN TRY

        -- Record the time the entire batch started
        SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT 'Starting Bronze Layer Load';
        PRINT '================================================';


        -- =====================================================================
        -- Section 1: CRM Tables
        -- Loading 3 tables from the CRM source system
        -- =====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';


        -- ---------------------------------------------------------------------
        -- Table 1: bronze.crm_cust_info
        -- Source : E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_crm\cust_info.csv
        -- Contains customer master data — names, gender, marital status
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;  -- Clear old data before reloading

        PRINT '>> Inserting Data Into: bronze.crm_cust_info';
        BULK INSERT bronze.crm_cust_info
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,           -- Skip the header row in the CSV
            FIELDTERMINATOR = ',',  -- Columns are separated by commas
            TABLOCK                 -- Lock the entire table during load (faster)
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 2: bronze.crm_prd_info
        -- Source : datasets/source_crm/prd_info.csv
        -- Contains product master data — names, cost, product line, dates
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into: bronze.crm_prd_info';
        BULK INSERT bronze.crm_prd_info
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 3: bronze.crm_sales_details
        -- Source : datasets/source_crm/sales_details.csv
        -- Contains sales transactions — orders, quantities, prices, dates
        -- Note: Date columns arrive as integers (YYYYMMDD) — converted in silver
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into: bronze.crm_sales_details';
        BULK INSERT bronze.crm_sales_details
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- =====================================================================
        -- Section 2: ERP Tables
        -- Loading 3 tables from the ERP source system
        -- =====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';


        -- ---------------------------------------------------------------------
        -- Table 4: bronze.erp_loc_a101
        -- Source : datasets/source_erp/loc_a101.csv
        -- Contains customer country/location data from ERP
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_erp\loc_a101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 5: bronze.erp_cust_az12
        -- Source : datasets/source_erp/cust_az12.csv
        -- Contains additional customer info — birthdate and gender from ERP
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_erp\cust_az12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 6: bronze.erp_px_cat_g1v2
        -- Source : datasets/source_erp/px_cat_g1v2.csv
        -- Contains product category and subcategory data from ERP
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'E:\Learning 2026\Data Engineering\sql-data-warehouse-project\datasets\source_erp\px_cat_g1v2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- All 6 tables loaded successfully — print total time
        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Bronze Layer Load Completed Successfully';
        PRINT '   - Total Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';

    END TRY

    -- =========================================================================
    -- Error Handler
    -- If anything goes wrong during the load, we land here instead of crashing.
    -- The error details are printed so we can debug exactly what failed.
    -- =========================================================================
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
        PRINT '   - Message : ' + ERROR_MESSAGE();
        PRINT '   - Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '   - State   : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
    END CATCH

END
-- =============================================================================
-- End of proc_load_bronze.sql
-- Next step: Run scripts/silver/proc_load_silver.sql
-- =============================================================================