-- =============================================================================
-- Script   : ddl_silver.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script defines the table structure (DDL) for all six tables
--     in the 'silver' schema. These tables hold cleaned and standardized
--     data that has been transformed from the bronze layer.
--
-- How Silver Differs from Bronze:
--     Bronze  → Raw data, loaded as-is from CSV files, no changes at all
--     Silver  → Same tables but with data quality issues fixed:
--                 - Date columns converted from INT to proper DATE type
--                 - NULL values handled
--                 - Inconsistent values standardized (e.g., gender codes)
--                 - Duplicate records removed
--                 - A new technical column (dwh_create_date) added to each table
--
-- What is dwh_create_date?
--     This is a system-generated technical column added to every silver table.
--     It automatically records the exact timestamp when each row was inserted
--     into the silver layer. Useful for auditing and debugging data loads.
--     It is NOT from the source system — we create it ourselves.
--
-- Important Notes:
--     - Each table is dropped and recreated fresh on every run.
--     - Data is loaded separately via the silver stored procedure (load_silver).
--     - Table and column names are kept the same as bronze for easy traceability.
--
-- Execution Order:
--     Run this AFTER ddl_bronze.sql and proc_load_bronze.sql
--     Run this BEFORE proc_load_silver.sql
-- =============================================================================


-- =============================================================================
-- CRM Tables
-- Source: Customer Relationship Management system (cleaned version)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Table: silver.crm_cust_info
-- Source: bronze.crm_cust_info
-- Changes from Bronze:
--     - Gender and marital status values will be standardized in load script
--       (e.g., 'M' → 'Male', 'S' → 'Single')
--     - dwh_create_date added to track when the record was loaded
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id             INT,                              -- Unique numeric customer ID
    cst_key            NVARCHAR(50),                     -- Alphanumeric customer code
    cst_firstname      NVARCHAR(50),                     -- Customer first name
    cst_lastname       NVARCHAR(50),                     -- Customer last name
    cst_marital_status NVARCHAR(50),                     -- Marital status (standardized: 'Married', 'Single')
    cst_gndr           NVARCHAR(50),                     -- Gender (standardized: 'Male', 'Female', 'n/a')
    cst_create_date    DATE,                             -- Date the customer record was created in CRM
    dwh_create_date    DATETIME2 DEFAULT GETDATE()       -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- -----------------------------------------------------------------------------
-- Table: silver.crm_prd_info
-- Source: bronze.crm_prd_info
-- Changes from Bronze:
--     - cat_id added as a new derived column (extracted from prd_key)
--       to link products to the ERP category table
--     - prd_start_dt and prd_end_dt converted from DATETIME to DATE
--     - dwh_create_date added
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,                                 -- Unique numeric product ID
    cat_id          NVARCHAR(50),                        -- Derived category ID (extracted from prd_key, links to ERP)
    prd_key         NVARCHAR(50),                        -- Alphanumeric product code
    prd_nm          NVARCHAR(50),                        -- Product name
    prd_cost        INT,                                 -- Product cost in whole currency units
    prd_line        NVARCHAR(50),                        -- Product line or series (e.g., Road, Mountain)
    prd_start_dt    DATE,                                -- Date product became available (cleaned from DATETIME)
    prd_end_dt      DATE,                                -- Date product was discontinued (NULL if still active)
    dwh_create_date DATETIME2 DEFAULT GETDATE()          -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- -----------------------------------------------------------------------------
-- Table: silver.crm_sales_details
-- Source: bronze.crm_sales_details
-- Changes from Bronze:
--     - sls_order_dt, sls_ship_dt, sls_due_dt converted from INT (YYYYMMDD)
--       to proper DATE type — this is the biggest change in this table
--     - Invalid dates (e.g., 0 or negative values) handled in load script
--     - dwh_create_date added
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),                        -- Sales order number (e.g., SO54496)
    sls_prd_key     NVARCHAR(50),                        -- Product key linking to crm_prd_info
    sls_cust_id     INT,                                 -- Customer ID linking to crm_cust_info
    sls_order_dt    DATE,                                -- Order date (converted from INT to DATE)
    sls_ship_dt     DATE,                                -- Shipping date (converted from INT to DATE)
    sls_due_dt      DATE,                                -- Payment due date (converted from INT to DATE)
    sls_sales       INT,                                 -- Total sales amount for the line item
    sls_quantity    INT,                                 -- Number of units ordered
    sls_price       INT,                                 -- Price per unit
    dwh_create_date DATETIME2 DEFAULT GETDATE()          -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- =============================================================================
-- ERP Tables
-- Source: Enterprise Resource Planning system (cleaned version)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Table: silver.erp_loc_a101
-- Source: bronze.erp_loc_a101
-- Changes from Bronze:
--     - Country names standardized (e.g., 'DE' → 'Germany', 'US' → 'United States')
--     - Leading/trailing spaces trimmed from cid column
--     - dwh_create_date added
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid             NVARCHAR(50),                        -- Customer ID (cleaned to match crm_cust_info)
    cntry           NVARCHAR(50),                        -- Country name (standardized full name)
    dwh_create_date DATETIME2 DEFAULT GETDATE()          -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- -----------------------------------------------------------------------------
-- Table: silver.erp_cust_az12
-- Source: bronze.erp_cust_az12
-- Changes from Bronze:
--     - Future birthdates removed (invalid data)
--     - Gender values standardized to match CRM format ('Male', 'Female', 'n/a')
--     - dwh_create_date added
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid             NVARCHAR(50),                        -- Customer ID (links to crm_cust_info after cleaning)
    bdate           DATE,                                -- Customer date of birth (invalid future dates removed)
    gen             NVARCHAR(50),                        -- Gender (standardized: 'Male', 'Female', 'n/a')
    dwh_create_date DATETIME2 DEFAULT GETDATE()          -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- -----------------------------------------------------------------------------
-- Table: silver.erp_px_cat_g1v2
-- Source: bronze.erp_px_cat_g1v2
-- Changes from Bronze:
--     - Whitespace trimmed from all columns
--     - dwh_create_date added
-- -----------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),                        -- Product ID (links to crm_prd_info)
    cat             NVARCHAR(50),                        -- Product category (e.g., Bikes, Components)
    subcat          NVARCHAR(50),                        -- Product subcategory (e.g., Road Bikes, Helmets)
    maintenance     NVARCHAR(50),                        -- Whether product requires maintenance (Yes / No)
    dwh_create_date DATETIME2 DEFAULT GETDATE()          -- Auto-filled timestamp: when this row was loaded into silver
);
GO


-- =============================================================================
-- Silver layer table definitions complete.
-- 6 tables created: 3 from CRM, 3 from ERP.
-- Next step: Run scripts/silver/proc_load_silver.sql to populate these tables.
-- =============================================================================