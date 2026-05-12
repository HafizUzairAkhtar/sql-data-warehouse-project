-- =============================================================================
-- Script   : quality_checks_gold.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script runs data quality checks on all three views in the gold layer
--     after the gold layer DDL script has been executed.
--
--     It validates that the star schema is correctly structured and that the
--     data integrated from the silver layer is consistent and analytically sound.
--
-- What Is Being Checked:
--     1. Uniqueness of surrogate keys in both dimension views
--     2. Referential integrity between the fact view and dimension views
--        (every sales record must link to a valid product and customer)
--
-- How to Use:
--     - Run this script AFTER executing ddl_gold.sql
--     - Every check has an expected result written above it
--     - If a check returns rows → something is wrong and needs investigation
--     - If a check returns no rows → that check passed ✓
--
-- Execution Order:
--     Run AFTER ddl_gold.sql (and after silver layer is fully loaded)
-- =============================================================================


-- =============================================================================
-- Section 1: gold.dim_customers
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 1: Duplicate Surrogate Keys in Customer Dimension
-- Why: customer_key is the surrogate primary key of this dimension view.
--      ROW_NUMBER() should guarantee uniqueness — if duplicates exist,
--      it means the underlying silver data has changed in an unexpected way
--      or the view logic has a bug that needs to be investigated.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- =============================================================================
-- Section 2: gold.dim_products
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 2: Duplicate Surrogate Keys in Product Dimension
-- Why: product_key is the surrogate primary key of this dimension view.
--      ROW_NUMBER() should guarantee uniqueness — duplicates here would cause
--      fan-out in the fact table when joining, inflating sales figures in reports.
--      If this fails, investigate whether prd_end_dt IS NULL filter is working
--      correctly and that no two active products share the same prd_key.
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- =============================================================================
-- Section 3: gold.fact_sales
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Check 3: Referential Integrity Between Fact and Dimension Views
-- Why: Every row in the fact view must link to a valid customer AND a valid
--      product in their respective dimension views. Orphaned fact rows —
--      those with no matching dimension record — break reports and dashboards
--      by producing NULLs in dimension columns (e.g., missing product names
--      or customer details on sales reports).
--
--      Common causes of orphaned rows:
--        - A product was retired (prd_end_dt IS NOT NULL) and filtered out
--          of dim_products, but its sales records still exist in fact_sales
--        - A customer key mismatch between CRM and the silver layer join
--
-- Expected Result: No rows returned
-- -----------------------------------------------------------------------------
SELECT
    f.order_number,
    f.product_key,
    f.customer_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL
   OR c.customer_key IS NULL;


-- =============================================================================
-- End of quality_checks_gold.sql
-- If all checks pass (return no rows) → Gold layer is clean and analytically sound.
-- These views are ready to be connected to BI tools (Power BI, Tableau, etc.)
-- =============================================================================