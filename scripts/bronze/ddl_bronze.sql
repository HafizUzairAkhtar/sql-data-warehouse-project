-- =============================================================================
-- Script   : ddl_bronze.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This script defines the table structure (DDL) for all six tables
--     in the 'bronze' schema. These tables hold raw, unprocessed data
--     ingested directly from two source systems — CRM and ERP.
--
-- Source Systems:
--     CRM  → 3 tables  (customer info, product info, sales details)
--     ERP  → 3 tables  (customer extras, customer locations, product categories)
--
-- Important Notes:
--     - No data transformations are applied at this layer.
--     - Column names and data types match the source files as closely as possible.
--     - Each table is dropped and recreated to ensure a clean structure on every run.
--     - Data is loaded separately via the bronze stored procedure (load_bronze).
--
-- Execution Order:
--     Run this script AFTER init_database.sql and BEFORE load_bronze.sql
-- =============================================================================


-- =============================================================================
-- CRM Tables
-- Source: Customer Relationship Management system
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Table: bronze.crm_cust_info
-- Description: Customer master data from the CRM system.
--              Contains basic customer details like name, gender,
--              marital status, and the date the record was created.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,            -- Unique numeric ID for the customer
    cst_key             NVARCHAR(50),   -- Alphanumeric customer code
    cst_firstname       NVARCHAR(50),   -- Customer's first name
    cst_lastname        NVARCHAR(50),   -- Customer's last name
    cst_marital_status  NVARCHAR(50),   -- Marital status (e.g., M = Married, S = Single)
    cst_gndr            NVARCHAR(50),   -- Gender (e.g., M, F — standardized in silver layer)
    cst_create_date     DATE            -- Date the customer record was created in CRM
);
GO


-- -----------------------------------------------------------------------------
-- Table: bronze.crm_prd_info
-- Description: Product master data from the CRM system.
--              Contains product details including cost, product line,
--              and the date range during which the product was active.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,            -- Unique numeric ID for the product
    prd_key      NVARCHAR(50),   -- Alphanumeric product code
    prd_nm       NVARCHAR(50),   -- Product name
    prd_cost     INT,            -- Product cost in whole currency units
    prd_line     NVARCHAR(50),   -- Product line or series (e.g., Road, Mountain)
    prd_start_dt DATETIME,       -- Date the product became available
    prd_end_dt   DATETIME        -- Date the product was discontinued (NULL if still active)
);
GO


-- -----------------------------------------------------------------------------
-- Table: bronze.crm_sales_details
-- Description: Transactional sales records from the CRM system.
--              Each row represents one line item in a sales order.
--              Date columns are stored as integers in the source (YYYYMMDD format)
--              and will be converted to proper DATE types in the silver layer.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),   -- Sales order number (e.g., SO54496)
    sls_prd_key  NVARCHAR(50),   -- Product key linking to crm_prd_info
    sls_cust_id  INT,            -- Customer ID linking to crm_cust_info
    sls_order_dt INT,            -- Order date stored as integer (YYYYMMDD) — raw format
    sls_ship_dt  INT,            -- Shipping date stored as integer (YYYYMMDD) — raw format
    sls_due_dt   INT,            -- Due date stored as integer (YYYYMMDD) — raw format
    sls_sales    INT,            -- Total sales amount for this line item
    sls_quantity INT,            -- Number of units ordered
    sls_price    INT             -- Price per unit
);
GO


-- =============================================================================
-- ERP Tables
-- Source: Enterprise Resource Planning system
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Table: bronze.erp_loc_a101
-- Description: Customer location data from the ERP system.
--              Contains country information for each customer.
--              Joined to CRM customer data in the gold layer.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    cid    NVARCHAR(50),   -- Customer ID (links to crm_cust_info after cleaning)
    cntry  NVARCHAR(50)    -- Country name (raw — standardized in silver layer)
);
GO


-- -----------------------------------------------------------------------------
-- Table: bronze.erp_cust_az12
-- Description: Additional customer details from the ERP system.
--              Provides birthdate and gender data not available in the CRM.
--              This table enriches customer records in the gold layer.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    cid    NVARCHAR(50),   -- Customer ID (links to crm_cust_info after cleaning)
    bdate  DATE,           -- Customer date of birth
    gen    NVARCHAR(50)    -- Gender (raw — standardized in silver layer)
);
GO


-- -----------------------------------------------------------------------------
-- Table: bronze.erp_px_cat_g1v2
-- Description: Product category data from the ERP system.
--              Contains category, subcategory, and maintenance flag for products.
--              Joined to CRM product data in the gold layer.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           NVARCHAR(50),   -- Product ID (links to crm_prd_info)
    cat          NVARCHAR(50),   -- Product category (e.g., Bikes, Components)
    subcat       NVARCHAR(50),   -- Product subcategory (e.g., Road Bikes, Helmets)
    maintenance  NVARCHAR(50)    -- Whether the product requires maintenance (Yes/No)
);
GO


-- =============================================================================
-- Bronze layer table definitions complete.
-- 6 tables created: 3 from CRM, 3 from ERP.
-- Next step: Run scripts/bronze/load_bronze.sql to populate these tables.
-- =============================================================================