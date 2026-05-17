-- =========================================
-- PART A - ENVIRONMENT + CLEANUP
-- =========================================

USE AdventureWorks2022;
GO

-- =========================================
-- Drop child table first (FK dependency)
-- =========================================
DROP TABLE IF EXISTS EntryTest.OrderItemMini;
GO

DROP TABLE IF EXISTS EntryTest.OrderMini;
GO

DROP TABLE IF EXISTS EntryTest.CustomerMini;
GO

-- =========================================
-- Optional: Drop schema only if empty
-- =========================================
IF EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'EntryTest'
)
AND NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE schema_id = SCHEMA_ID('EntryTest')
)
BEGIN
    DROP SCHEMA EntryTest;
END
GO

-- =========================================
-- PART B - CREATE SCHEMA + TABLES
-- =========================================

USE AdventureWorks2022;
GO

-- =========================================
-- Create schema if it doesn't exist
-- =========================================
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'EntryTest'
)
BEGIN
    EXEC('CREATE SCHEMA EntryTest');
END
GO

-- =========================================
-- B2 - CustomerMini Table
-- =========================================
CREATE TABLE EntryTest.CustomerMini
(
    CustomerMiniID INT IDENTITY(1,1) PRIMARY KEY,

    CustomerID INT NOT NULL UNIQUE,

    AccountNumber NVARCHAR(10) NOT NULL,

    CustomerType NCHAR(1) NOT NULL
        CHECK (CustomerType IN ('I','S')),

    CreatedAt DATETIME2(0) NOT NULL
        DEFAULT SYSDATETIME()
);
GO

-- =========================================
-- B3 - OrderMini Table
-- =========================================
CREATE TABLE EntryTest.OrderMini
(
    OrderMiniID INT IDENTITY(1,1) PRIMARY KEY,

    SalesOrderID INT NOT NULL UNIQUE,

    CustomerID INT NOT NULL,

    OrderDate DATE NOT NULL,

    SubTotal MONEY NOT NULL
        CHECK (SubTotal >= 0),

    TaxAmt MONEY NOT NULL
        CHECK (TaxAmt >= 0),

    Freight MONEY NOT NULL
        CHECK (Freight >= 0),

    TotalDue MONEY NOT NULL
        CHECK (TotalDue >= 0)
);
GO

-- =========================================
-- B4 - OrderItemMini Table
-- =========================================
CREATE TABLE EntryTest.OrderItemMini
(
    OrderItemMiniID INT IDENTITY(1,1) PRIMARY KEY,

    SalesOrderID INT NOT NULL,

    SalesOrderDetailID INT NOT NULL,

    ProductID INT NOT NULL,

    OrderQty SMALLINT NOT NULL
        CHECK (OrderQty > 0),

    UnitPrice MONEY NOT NULL
        CHECK (UnitPrice >= 0),

    UnitPriceDiscount MONEY NOT NULL
        DEFAULT (0)
        CHECK (UnitPriceDiscount BETWEEN 0 AND 1),

    LineTotal MONEY NOT NULL
        CHECK (LineTotal >= 0),

    -- Composite unique constraint
    CONSTRAINT UQ_OrderItemMini
        UNIQUE (SalesOrderID, SalesOrderDetailID),

    -- Foreign key
    CONSTRAINT FK_OrderItemMini_OrderMini
        FOREIGN KEY (SalesOrderID)
        REFERENCES EntryTest.OrderMini(SalesOrderID)
);
GO

-- =========================================
-- PART C - BASIC DML
-- =========================================

USE AdventureWorks2022;
GO

-- =========================================
-- Clear existing customers
-- =========================================
DELETE FROM EntryTest.CustomerMini;
GO

-- =========================================
-- Insert customers that EXIST in OrderMini
-- This guarantees JOIN results
-- =========================================
INSERT INTO EntryTest.CustomerMini
(
    CustomerID,
    AccountNumber,
    CustomerType
)
SELECT DISTINCT TOP (50)
    c.CustomerID,
    c.AccountNumber,

    CASE
        WHEN c.StoreID IS NULL THEN 'I'
        ELSE 'S'
    END AS CustomerType

FROM Sales.Customer c
INNER JOIN EntryTest.OrderMini o
    ON c.CustomerID = o.CustomerID

ORDER BY c.CustomerID ASC;
GO
-- =========================================
-- C2 - Insert EXACTLY 200 most recent orders
-- =========================================
INSERT INTO EntryTest.OrderMini
(
    SalesOrderID,
    CustomerID,
    OrderDate,
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue
)
SELECT TOP (200)
    SalesOrderID,
    CustomerID,
    CAST(OrderDate AS DATE),
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue
FROM Sales.SalesOrderHeader
ORDER BY OrderDate DESC,
         SalesOrderID DESC;
GO

-- =========================================
-- C3 - Insert order items
-- Only for SalesOrderID existing in OrderMini
-- =========================================
INSERT INTO EntryTest.OrderItemMini
(
    SalesOrderID,
    SalesOrderDetailID,
    ProductID,
    OrderQty,
    UnitPrice,
    UnitPriceDiscount,
    LineTotal
)
SELECT
    d.SalesOrderID,
    d.SalesOrderDetailID,
    d.ProductID,
    d.OrderQty,
    d.UnitPrice,
    d.UnitPriceDiscount,
    d.LineTotal
FROM Sales.SalesOrderDetail d
INNER JOIN EntryTest.OrderMini o
    ON d.SalesOrderID = o.SalesOrderID;
GO

-- =========================================
-- E1 - UNION
-- Combined People Names
-- =========================================

SELECT NameValue
FROM
(
    SELECT TOP (10) FirstName AS NameValue
    FROM Person.Person

    UNION

    SELECT TOP (10) LastName AS NameValue
    FROM Person.Person
) AS X
ORDER BY NameValue;

-- =========================================
-- E2 - UNION ALL
-- Two Product Lists
-- =========================================

SELECT
    'FinishedGoods' AS ListType,
    ProductID,
    Name
FROM
(
    SELECT TOP (10)
        ProductID,
        Name
    FROM Production.Product
    WHERE FinishedGoodsFlag = 1
    ORDER BY ProductID ASC
) AS FinishedGoods

UNION ALL

SELECT
    'NotFinished' AS ListType,
    ProductID,
    Name
FROM
(
    SELECT TOP (10)
        ProductID,
        Name
    FROM Production.Product
    WHERE FinishedGoodsFlag = 0
    ORDER BY ProductID ASC
) AS NotFinished;
GO

-- =========================================
-- F1 - INNER JOIN
-- Orders with Customer Info
-- =========================================

SELECT
    o.SalesOrderID,
    o.OrderDate,
    c.CustomerID,
    c.AccountNumber,
    ROUND(o.TotalDue, 2) AS TotalDue
FROM EntryTest.OrderMini o
INNER JOIN EntryTest.CustomerMini c
    ON o.CustomerID = c.CustomerID
ORDER BY o.OrderDate DESC;
GO

-- =========================================
-- F2 - LEFT JOIN
-- Customers with or without Orders
-- =========================================

SELECT
    c.CustomerID,
    c.AccountNumber,
    o.SalesOrderID,
    o.OrderDate
FROM EntryTest.CustomerMini c
LEFT JOIN EntryTest.OrderMini o
    ON c.CustomerID = o.CustomerID
ORDER BY c.CustomerID ASC;
GO

-- =========================================
-- F3 - JOIN + GROUP BY
-- Order Totals Per Customer
-- =========================================

SELECT
    c.CustomerID,
    COUNT(o.SalesOrderID) AS OrderCount,
    ROUND(SUM(o.TotalDue), 2) AS TotalSpent
FROM EntryTest.CustomerMini c
INNER JOIN EntryTest.OrderMini o
    ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID
ORDER BY TotalSpent DESC;
GO
