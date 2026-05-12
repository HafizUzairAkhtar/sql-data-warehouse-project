-- =============================================================================
-- Script   : quality_checks_silver.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script runs data quality checks on all six tables in the silver layer
--     after the silver load procedure has been executed.
--
--     It validates that the transformations applied in proc_load_silver.sql
--     worked correctly and that the data is clean, consistent, and ready
--     to be used in the gold layer.
--
-- What Is Being Checked:
--     1. No NULL or duplicate primary keys
--     2. No unwanted leading/trailing spaces in text columns
--     3. Standardized values (gender, marital status, country, product line)
--     4. Valid date ranges — no future birthdates, no invalid order dates
--     5. Data consistency — sales must equal quantity × price
--
-- How to Use:
--     - Run this script AFTER executing proc_load_silver.sql
--     - Every check has an expected result written above it
--     - If a check returns rows → something is wrong and needs investigation
--     - If a check returns no rows → that check passed ✓
--
-- Execution Order:
--     Run AFTER proc_load_silver.sql
-- =============================================================================


-- =============================================================================
-- Section 1: silver.crm_cust_info
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 1: NULL or Duplicate Customer IDs
-- Why: cst_id is the primary key — every customer must have a unique ID.
--      Duplicates mean deduplication in the load script didn't work correctly.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    cst_id,
    COUNT(*) AS record_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;


-- -----------------------------------------------------------------------------
-- Check 2: Unwanted Spaces in Customer Key
-- Why: Extra spaces in cst_key cause join failures in the gold layer.
--      TRIM() should have removed them during the silver load.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);


-- -----------------------------------------------------------------------------
-- Check 3: Marital Status Standardization
-- Why: We transformed 'S' → 'Single' and 'M' → 'Married' in the load script.
--      This check shows all distinct values so we can verify only
--      'Single', 'Married', and 'n/a' exist — nothing else.
-- Expected Result: Only 'Single', 'Married', 'n/a'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;


-- -----------------------------------------------------------------------------
-- Check 4: Gender Standardization
-- Why: We transformed 'F' → 'Female' and 'M' → 'Male' in the load script.
--      This verifies only clean values exist.
-- Expected Result: Only 'Female', 'Male', 'n/a'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;


-- =============================================================================
-- Section 2: silver.crm_prd_info
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 5: NULL or Duplicate Product IDs
-- Why: prd_id is the primary key — every product must have a unique ID.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    prd_id,
    COUNT(*) AS record_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;


-- -----------------------------------------------------------------------------
-- Check 6: Unwanted Spaces in Product Name
-- Why: Extra spaces in product names look unprofessional in reports
--      and can cause mismatches in lookups.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);


-- -----------------------------------------------------------------------------
-- Check 7: NULL or Negative Product Cost
-- Why: A product with NULL or negative cost is invalid data.
--      The load script replaced NULLs with 0 — this verifies that worked.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;


-- -----------------------------------------------------------------------------
-- Check 8: Product Line Standardization
-- Why: We transformed single-letter codes ('M', 'R', 'S', 'T') into
--      full readable names. This verifies the transformation worked.
-- Expected Result: Only 'Mountain', 'Road', 'Other Sales', 'Touring', 'n/a'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- -----------------------------------------------------------------------------
-- Check 9: Invalid Date Order (Start Date After End Date)
-- Why: A product cannot end before it starts — this would be corrupt data.
--      The LEAD() calculation in the load script should prevent this.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    prd_id,
    prd_nm,
    prd_start_dt,
    prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- =============================================================================
-- Section 3: silver.crm_sales_details
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 10: Invalid Date Values in Source (Bronze Check)
-- Why: The bronze layer stores dates as integers (YYYYMMDD format).
--      This checks the raw bronze data for values that are 0, negative,
--      too old (before 1900), or impossibly far in the future (after 2050).
--      Useful to understand how many bad dates existed before cleaning.
-- Expected Result: These rows should all be NULL in the silver layer
-- -----------------------------------------------------------------------------
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) != 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;


-- -----------------------------------------------------------------------------
-- Check 11: Order Date After Ship Date or Due Date
-- Why: Logically, an order must be placed BEFORE it is shipped or payment
--      is due. If order date is later than ship/due date, the data is wrong.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    sls_ord_num,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;


-- -----------------------------------------------------------------------------
-- Check 12: Sales Consistency (Sales = Quantity × Price)
-- Why: The business rule is: Sales Amount = Quantity × Price.
--      If this doesn't hold, the data has calculation errors.
--      The load script recalculated sales where needed — this verifies it.
--      We also check for NULLs and zero/negative values.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales    IS NULL OR sls_sales    <= 0
   OR sls_quantity IS NULL OR sls_quantity <= 0
   OR sls_price    IS NULL OR sls_price    <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- =============================================================================
-- Section 4: silver.erp_cust_az12
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 13: Out-of-Range Birthdates
-- Why: A valid birthdate should be between 1924-01-01 and today.
--      Future dates are impossible. Dates before 1924 are extremely unlikely
--      for an active customer. The load script set future dates to NULL —
--      this verifies no invalid dates remain.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > GETDATE();


-- -----------------------------------------------------------------------------
-- Check 14: Gender Standardization (ERP)
-- Why: ERP had multiple formats — 'F', 'FEMALE', 'M', 'MALE', etc.
--      We standardized all to 'Female', 'Male', or 'n/a'.
--      This confirms only those three values exist.
-- Expected Result: Only 'Female', 'Male', 'n/a'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


-- =============================================================================
-- Section 5: silver.erp_loc_a101
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 15: Country Name Standardization
-- Why: ERP stored country codes like 'DE', 'US', 'USA'.
--      We converted them to full names like 'Germany', 'United States'.
--      This shows all distinct values to confirm no raw codes remain.
-- Expected Result: Full country names only — no raw codes like 'DE' or 'US'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;


-- =============================================================================
-- Section 6: silver.erp_px_cat_g1v2
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 16: Unwanted Spaces in Category Columns
-- Why: Extra spaces in category, subcategory, or maintenance columns
--      cause mismatches when joining with other tables in the gold layer.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat         != TRIM(cat)
   OR subcat      != TRIM(subcat)
   OR maintenance != TRIM(maintenance);


-- -----------------------------------------------------------------------------
-- Check 17: Maintenance Value Standardization
-- Why: The maintenance column should only contain 'Yes' or 'No'.
--      This confirms no unexpected values exist.
-- Expected Result: Only 'Yes' and 'No'
-- -----------------------------------------------------------------------------
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;


-- =============================================================================
-- End of quality_checks_silver.sql
-- If all checks pass (return no rows or expected distinct values only)
-- → Silver layer is clean and ready for gold layer modeling
-- Next step: Run scripts/gold/ to create the analytical views
-- =============================================================================