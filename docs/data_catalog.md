# Data Catalog

This document describes the Gold Layer tables used in this data warehouse project.

The Gold Layer contains business-ready data models designed for analytics and reporting. These objects are organized into **dimension tables** and **fact tables**, so users can easily analyze customers, products, and sales activity.

---

## Table of Contents

1. [Gold Layer Overview](#gold-layer-overview)
2. [gold.dim_customers](#golddim_customers)
3. [gold.dim_products](#golddim_products)
4. [gold.fact_sales](#goldfact_sales)
5. [Table Relationships](#table-relationships)

---

## Gold Layer Overview

The Gold Layer is the final business-facing layer of the data warehouse. It contains cleaned, transformed, and structured data that is ready for reporting, dashboards, and ad-hoc analysis.

| Table Name | Type | Description |
|------------|------|-------------|
| `gold.dim_customers` | Dimension | Stores customer profile, demographic, and geographic details |
| `gold.dim_products` | Dimension | Stores product, category, cost, and product line details |
| `gold.fact_sales` | Fact | Stores sales transactions connected to customers and products |

---

## gold.dim_customers

### Purpose

`gold.dim_customers` stores customer information in a business-friendly format. It includes customer identifiers, names, location details, demographic attributes, and record creation dates.

This table is used to analyze sales and customer behavior by customer, country, gender, marital status, and age-related attributes.

### Grain

Each row represents one customer record.

### Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `customer_key` | `INT` | Surrogate key that uniquely identifies each customer record in the Gold Layer |
| `customer_id` | `INT` | Source system customer identifier |
| `customer_number` | `NVARCHAR(50)` | Alphanumeric customer number used for tracking and reference |
| `first_name` | `NVARCHAR(50)` | Customer's first name |
| `last_name` | `NVARCHAR(50)` | Customer's last name or family name |
| `country` | `NVARCHAR(50)` | Customer's country of residence |
| `marital_status` | `NVARCHAR(50)` | Customer's marital status, such as `Married` or `Single` |
| `gender` | `NVARCHAR(50)` | Customer's gender, such as `Male`, `Female`, or `n/a` |
| `birthdate` | `DATE` | Customer's date of birth |
| `create_date` | `DATE` | Date when the customer record was created in the source system |

---

## gold.dim_products

### Purpose

`gold.dim_products` stores product information and product attributes. It includes product identifiers, product names, category details, maintenance indicators, cost, product line, and product start dates.

This table is used to analyze sales performance by product, category, subcategory, product line, and cost-related attributes.

### Grain

Each row represents one product record.

### Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `product_key` | `INT` | Surrogate key that uniquely identifies each product record in the Gold Layer |
| `product_id` | `INT` | Source system product identifier |
| `product_number` | `NVARCHAR(50)` | Alphanumeric product code used for tracking, categorization, or inventory reference |
| `product_name` | `NVARCHAR(50)` | Descriptive product name, including key details such as type, color, or size |
| `category_id` | `NVARCHAR(50)` | Identifier for the product category |
| `category` | `NVARCHAR(50)` | High-level product category, such as `Bikes` or `Components` |
| `subcategory` | `NVARCHAR(50)` | More detailed product classification within the main category |
| `maintenance_required` | `NVARCHAR(50)` | Indicates whether the product requires maintenance, such as `Yes` or `No` |
| `cost` | `INT` | Product cost stored as a whole currency value |
| `product_line` | `NVARCHAR(50)` | Product line or series, such as `Road` or `Mountain` |
| `start_date` | `DATE` | Date when the product became available for sale or use |

---

## gold.fact_sales

### Purpose

`gold.fact_sales` stores sales transaction data for analysis and reporting. It connects each sale to the related customer and product dimensions using surrogate keys.

This table is used to analyze revenue, order volume, product demand, customer purchases, and sales trends over time.

### Grain

Each row represents one sales order line item.

### Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `order_number` | `NVARCHAR(50)` | Unique sales order number, such as `SO54496` |
| `product_key` | `INT` | Foreign key that links the sale to `gold.dim_products` |
| `customer_key` | `INT` | Foreign key that links the sale to `gold.dim_customers` |
| `order_date` | `DATE` | Date when the order was placed |
| `shipping_date` | `DATE` | Date when the order was shipped to the customer |
| `due_date` | `DATE` | Date when the order payment was due |
| `sales_amount` | `INT` | Total sales amount for the order line item, stored as a whole currency value |
| `quantity` | `INT` | Number of product units ordered |
| `price` | `INT` | Price per product unit, stored as a whole currency value |

---

## Table Relationships

The Gold Layer follows a simple star schema design. The fact table stores measurable sales events, while the dimension tables provide descriptive context for analysis.

| Relationship | Description |
|--------------|-------------|
| `gold.fact_sales.customer_key` → `gold.dim_customers.customer_key` | Connects each sale to the customer who placed the order |
| `gold.fact_sales.product_key` → `gold.dim_products.product_key` | Connects each sale to the product that was ordered |

This structure makes it easier to build reports such as:

- Sales by customer
- Sales by country
- Sales by product
- Sales by category or subcategory
- Monthly or yearly sales trends
- Product performance analysis
