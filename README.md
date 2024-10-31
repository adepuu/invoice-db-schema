# Invoice Database Project Setup Guide

This repository contains the necessary files to set up and work with an invoice database system. Follow these instructions to get started with the database and learn how to perform various operations.

## 📁 Files Overview

- `Supabase_DEV_DB-2024_10_31_11_15_37-dump.sql` - Main database dump file
- `data-retrieve.sql` - SQL queries for retrieving data
- `example-insert-data.sql` - Example queries for inserting data
- `README.md` - This guide

## 🚀 Getting Started

### Prerequisites

- PostgreSQL installed on your system
- Basic knowledge of SQL commands
- A PostgreSQL client (pgAdmin, DBeaver, or psql)

### Database Setup

1. Create a new empty database:
```sql
CREATE DATABASE invoice_db;
```

2. Restore the database from the dump file:

Using DBeaver:
- Right-click on your database in the Database Navigator
- Select "Tools" -> "Restore Database"
- In the dialog box:
  - Format: "Custom or tar"
  - Input File: Browse to select `Supabase_DEV_DB-2024_10_31_11_15_37-dump.sql`
  - Click "Start"
- Wait for the restore process to complete

Using psql:
```bash
psql -U your_username -d invoice_db -f "Supabase_DEV_DB-2024_10_31_11_15_37-dump.sql"
```

Using pgAdmin:
- Right-click on your new database
- Select "Restore..."
- Choose the dump file
- Click "Restore"

## 📊 Working with the Database

### Retrieving Data

The `data-retrieve.sql` file contains various SQL queries that demonstrate how to:
- Query different tables
- Join related tables
- Filter and sort data
- Use aggregate functions

To try these queries in DBeaver:
1. Open `data-retrieve.sql`
2. Click "File" -> "Open File" or drag the file into DBeaver
3. To execute a single query:
   - Place your cursor within the query
   - Press Ctrl+Enter (Cmd+Enter on Mac)
   - Or click the "Execute SQL Statement" button
4. To execute multiple queries:
   - Select the queries you want to run
   - Press Alt+X (Option+X on Mac)
   - Or click the "Execute SQL Script" button
5. View results in the "Results" tab below

## 🔍 Practice Exercises

1. Basic Queries:
   - Try selecting all records from different tables
   - Filter records using WHERE clause
   - Sort results using ORDER BY

2. Intermediate Operations:
   - Join multiple tables
   - Use aggregate functions (COUNT, SUM, AVG)
   - Group results using GROUP BY

3. Advanced Tasks:
   - Create complex joins
   - Write subqueries
   - Perform data manipulation

### DBeaver Tips
- Use Ctrl+Space for SQL auto-completion
- Press F3 to open object properties
- Use Alt+X to execute selected queries
- Press Ctrl+/ to comment/uncomment lines
- Use Ctrl+Shift+E to explain query plan
