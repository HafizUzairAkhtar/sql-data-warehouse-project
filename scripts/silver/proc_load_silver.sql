-- =============================================================================
-- Script   : proc_load_silver.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script creates a stored procedure called 'silver.load_silver'.
--     It performs the ETL process from Bronze to Silver layer.
--
--     For each table it does three things:
--       1. Clears the silver table (TRUNCATE)
--       2. Reads data from the matching bronze table
--       3. Applies transformations and inserts clean data into silver
--
-- Transformations Applied:
--     crm_cust_info    → Removes duplicates, standardizes gender & marital status
--     crm_prd_info     → Extracts cat_id, cleans product line codes, fixes dates
--     crm_sales_details → Converts INT dates to DATE, recalculates wrong sales values
--     erp_cust_az12   → Removes 'NAS' prefix from IDs, removes future birthdates
--     erp_loc_a101    → Removes dashes from IDs, standardizes country names
--     erp_px_cat_g1v2 → Loaded as-is (already clean enough from bronze)
--
-- How to Run:
--     EXEC silver.load_silver;
--
-- Parameters:
--     None. This procedure takes no inputs and returns no values.
--
-- Execution Order:
--     Run this AFTER ddl_silver.sql (silver tables must exist first)
-- =============================================================================


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

    -- Variables to track how long each table load takes
    DECLARE @start_time       DATETIME,
            @end_time         DATETIME,
            @batch_start_time DATETIME,
            @batch_end_time   DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT 'Starting Silver Layer Load';
        PRINT '================================================';


        -- =====================================================================
        -- Section 1: CRM Tables
        -- =====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';


        -- ---------------------------------------------------------------------
        -- Table 1: silver.crm_cust_info
        -- Source  : bronze.crm_cust_info
        --
        -- Transformations:
        --   1. Remove duplicates using ROW_NUMBER()
        --      Some customers appear more than once in CRM. We keep only
        --      the most recent record per customer (latest cst_create_date).
        --   2. Filter out NULL customer IDs — they are useless records
        --   3. TRIM() removes leading/trailing spaces from name columns
        --   4. Standardize marital status: 'S' → 'Single', 'M' → 'Married'
        --   5. Standardize gender: 'F' → 'Female', 'M' → 'Male'
        --      Anything else becomes 'n/a' so we never have mystery values
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname)     AS cst_firstname,   -- Remove any extra spaces
            TRIM(cst_lastname)      AS cst_lastname,     -- Remove any extra spaces
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'                               -- Unknown values → 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'                               -- Unknown values → 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            -- Subquery: assign a row number per customer ordered by most recent date
            -- flag_last = 1 means this is the most recent record for that customer
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id           -- Group by customer
                    ORDER BY cst_create_date DESC -- Most recent first
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL              -- Skip records with no customer ID
        ) t
        WHERE flag_last = 1;                      -- Keep only the latest record per customer

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 2: silver.crm_prd_info
        -- Source  : bronze.crm_prd_info
        --
        -- Transformations:
        --   1. Extract cat_id from prd_key
        --      The first 5 characters of prd_key contain the category ID.
        --      We extract it and replace '-' with '_' to match ERP format.
        --      Example: 'AC-He-...' → 'AC_He'
        --   2. Extract clean prd_key by removing the first 6 characters
        --      (the category prefix we just extracted + the dash separator)
        --   3. Replace NULL cost with 0 using ISNULL()
        --   4. Standardize product line codes:
        --      'M' → 'Mountain', 'R' → 'Road', 'S' → 'Other Sales', 'T' → 'Touring'
        --   5. Convert prd_start_dt from DATETIME to DATE
        --   6. Calculate prd_end_dt using LEAD() window function:
        --      End date = one day before the next product version's start date.
        --      This handles products that were updated over time.
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,       -- Extract & clean category ID
            SUBSTRING(prd_key, 7, LEN(prd_key))          AS prd_key,     -- Remove category prefix from key
            prd_nm,
            ISNULL(prd_cost, 0)                           AS prd_cost,    -- Replace NULL cost with 0
            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,                  -- Convert DATETIME → DATE
            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY prd_key          -- Group by product
                    ORDER BY prd_start_dt         -- Order versions by start date
                ) - 1                             -- Subtract 1 day from next version's start
                AS DATE
            ) AS prd_end_dt                                               -- Result = end of current version
        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 3: silver.crm_sales_details
        -- Source  : bronze.crm_sales_details
        --
        -- Transformations:
        --   1. Convert date columns from INT (YYYYMMDD) to DATE type
        --      If the value is 0 or not exactly 8 digits → set to NULL
        --      Otherwise cast: INT → VARCHAR → DATE
        --   2. Fix sales amount:
        --      If sls_sales is NULL, zero, or doesn't match quantity × price
        --      → recalculate it as: quantity × ABS(price)
        --   3. Fix price:
        --      If sls_price is NULL or zero or negative
        --      → derive it as: sales / quantity (using NULLIF to avoid divide-by-zero)
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            -- Convert order date: INT → DATE, set NULL if invalid
            CASE
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            -- Convert ship date: INT → DATE, set NULL if invalid
            CASE
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            -- Convert due date: INT → DATE, set NULL if invalid
            CASE
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            -- Fix sales: recalculate if missing or inconsistent with quantity × price
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0
                  OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            -- Fix price: derive from sales/quantity if price is missing or invalid
            CASE
                WHEN sls_price IS NULL OR sls_price <= 0
                    THEN sls_sales / NULLIF(sls_quantity, 0)  -- NULLIF prevents divide-by-zero
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- =====================================================================
        -- Section 2: ERP Tables
        -- =====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';


        -- ---------------------------------------------------------------------
        -- Table 4: silver.erp_cust_az12
        -- Source  : bronze.erp_cust_az12
        --
        -- Transformations:
        --   1. Remove 'NAS' prefix from cid column
        --      Some customer IDs in ERP have 'NAS' at the start.
        --      We strip it so they match the CRM customer IDs correctly.
        --   2. Set future birthdates to NULL
        --      A birthdate in the future is clearly wrong data.
        --      We set those to NULL rather than keeping invalid values.
        --   3. Standardize gender values to match CRM format
        --      ERP uses multiple formats: 'F', 'FEMALE', 'M', 'MALE'
        --      We normalize all to: 'Female', 'Male', or 'n/a'
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            -- Remove 'NAS' prefix from customer ID if it exists
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,
            -- Set future birthdates to NULL — they are invalid
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            -- Normalize gender to consistent readable values
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 5: silver.erp_loc_a101
        -- Source  : bronze.erp_loc_a101
        --
        -- Transformations:
        --   1. Remove dashes from cid column using REPLACE()
        --      ERP stores IDs like 'AW-00000001' but CRM uses 'AW00000001'
        --      We remove the dash so both systems can be joined correctly
        --   2. Standardize country codes to full country names
        --      'DE' → 'Germany', 'US'/'USA' → 'United States'
        --      Empty or NULL → 'n/a'
        --      Anything already a full name → keep as-is with TRIM()
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,    -- Remove dashes from customer ID
            CASE
                WHEN TRIM(cntry) = 'DE'               THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA')     THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)                       -- Keep other full names, just trimmed
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- ---------------------------------------------------------------------
        -- Table 6: silver.erp_px_cat_g1v2
        -- Source  : bronze.erp_px_cat_g1v2
        --
        -- Transformations:
        --   None — this table is clean enough from the source.
        --   We load it as-is. The dwh_create_date is auto-filled by DEFAULT.
        -- ---------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        -- All 6 tables loaded successfully — print total time
        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Silver Layer Load Completed Successfully';
        PRINT '   - Total Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';

    END TRY

    -- =========================================================================
    -- Error Handler
    -- If anything fails during the silver load, we land here.
    -- Prints the exact error so you know which table and what went wrong.
    -- =========================================================================
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
        PRINT '   - Message : ' + ERROR_MESSAGE();
        PRINT '   - Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '   - State   : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
    END CATCH

END
-- =============================================================================
-- End of proc_load_silver.sql
-- Next step: Run scripts/gold/ to create the analytical views
-- =============================================================================