-- =============================================================================
-- Script   : init_database.sql
-- Author   : Uzair Akhtar
-- GitHub   : https://github.com/HafizUzairAkhtar
-- =============================================================================
-- Purpose:
--     This is the first script to run when setting up this project.
--     It creates the 'DataWarehouse' database from scratch and sets up
--     three schemas inside it — bronze, silver, and gold — which represent
--     the three layers of the Medallion Architecture used in this project.
--
-- What Each Schema Is For:
--     bronze  → Stores raw data exactly as received from source systems (CRM & ERP)
--     silver  → Stores cleaned and standardized data, ready for transformation
--     gold    → Stores business-ready views modeled as a star schema for analytics
--
-- Execution Order:
--     Run this script FIRST before any other script in the project.
--     After this, proceed to: scripts/bronze/ → scripts/silver/ → scripts/gold/
--
-- ⚠ WARNING:
--     This script will DROP the 'DataWarehouse' database if it already exists.
--     ALL existing data will be permanently deleted.
--     Do not run this on a database that contains data you want to keep.
-- =============================================================================


-- Step 1: Switch to the master database
--         We need to be in master before we can create or drop any database.
USE master;
GO


-- Step 2: Drop the existing DataWarehouse database if it exists
--         We first set it to SINGLE_USER mode to forcefully close any active
--         connections before dropping it. This prevents the drop from failing
--         due to open sessions.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO


-- Step 3: Create a fresh DataWarehouse database
CREATE DATABASE DataWarehouse;
GO


-- Step 4: Switch into the new database
USE DataWarehouse;
GO


-- Step 5: Create the three layer schemas
--         Each schema acts as a separate container for its layer's tables/views.
--         This keeps the layers isolated and easy to manage.

-- Bronze schema — raw ingestion layer
CREATE SCHEMA bronze;
GO

-- Silver schema — cleaning and transformation layer
CREATE SCHEMA silver;
GO

-- Gold schema — business-ready analytics layer
CREATE SCHEMA gold;
GO


-- =============================================================================
-- Setup complete.
-- Database 'DataWarehouse' is ready with schemas: bronze, silver, gold.
-- Next step: Run scripts in scripts/bronze/ to load raw data.
-- =============================================================================