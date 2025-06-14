--Drop and Recreate
IF OBJECT_ID('InsertOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE InsertOrderDetails;
GO

-- =====================================
-- STORED PROCEDURES
-- =====================================

--1)InsertOrderDetails Procedure
CREATE PROCEDURE InsertOrderDetails 
    @SalesOrderID INT,
    @ProductID INT,
    @OrderQty INT,
    @UnitPrice MONEY = NULL
AS
BEGIN
    DECLARE @ActualPrice MONEY

    -- Get price from product
    SELECT @ActualPrice = ListPrice 
    FROM Production.Product 
    WHERE ProductID = @ProductID;

    -- Fallback if no price is given
    IF @UnitPrice IS NULL
        SET @UnitPrice = @ActualPrice;

    -- Insert into SalesOrderDetail
    INSERT INTO Sales.SalesOrderDetail(SalesOrderID, ProductID, OrderQty, UnitPrice)
    VALUES (@SalesOrderID, @ProductID, @OrderQty, @UnitPrice);

    -- Check insertion
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.';
        RETURN;
    END

    PRINT 'Order inserted successfully.';
END;
GO



ALTER PROCEDURE InsertOrderDetails 
    @SalesOrderID INT,
    @ProductID INT,
    @OrderQty INT,
    @UnitPrice MONEY = NULL,
    @Discount FLOAT = 0
AS
BEGIN
    DECLARE @ActualPrice MONEY, @StockQty INT, @ReorderLevel INT;

    -- Get Unit Price if not provided
    SELECT @ActualPrice = ListPrice 
    FROM Production.Product 
    WHERE ProductID = @ProductID;

    IF @UnitPrice IS NULL
        SET @UnitPrice = @ActualPrice;

    -- Get stock and reorder level
    SELECT @StockQty = UnitsInStock, @ReorderLevel = ReorderLevel 
    FROM Production.Product 
    WHERE ProductID = @ProductID;

    -- Check stock
    IF @StockQty IS NULL OR @StockQty < @OrderQty
    BEGIN
        PRINT 'Not enough stock. Order failed.';
        RETURN;
    END

    -- Insert Order
    INSERT INTO Sales.SalesOrderDetail(SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount)
    VALUES (@SalesOrderID, @ProductID, @OrderQty, @UnitPrice, ISNULL(@Discount, 0));

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.';
        RETURN;
    END

    -- Update stock
    UPDATE Production.Product
    SET UnitsInStock = UnitsInStock - @OrderQty
    WHERE ProductID = @ProductID;

    -- Check Reorder Level
    IF EXISTS (
        SELECT 1 FROM Production.Product 
        WHERE ProductID = @ProductID AND UnitsInStock < ReorderLevel
    )
        PRINT 'Warning: Stock is below reorder level.';

    PRINT 'Order placed successfully.';
END;
GO

--2) UpdateOrderDetails Procedure
-- Drop the procedure first if needed
IF OBJECT_ID('UpdateOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE UpdateOrderDetails;
GO

-- Now create the procedure
CREATE PROCEDURE UpdateOrderDetails 
    @SalesOrderID INT,
    @ProductID INT,
    @UnitPrice MONEY = NULL,
    @OrderQty INT = NULL
AS
BEGIN
    UPDATE Sales.SalesOrderDetail
    SET 
        UnitPrice = ISNULL(@UnitPrice, UnitPrice),
        OrderQty = ISNULL(@OrderQty, OrderQty)
    WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID;
END;
GO

--3)GetOrderDetails Procedure
-- Optional: Drop if already exists
IF OBJECT_ID('GetOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE GetOrderDetails;
GO

-- Now create the procedure
CREATE PROCEDURE GetOrderDetails
    @SalesOrderID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @SalesOrderID)
    BEGIN
        PRINT 'The SalesOrderID ' + CAST(@SalesOrderID AS VARCHAR) + ' does not exist';
        RETURN 1;
    END

    SELECT * FROM Sales.SalesOrderDetail WHERE SalesOrderID = @SalesOrderID;
END;
GO

--4) DeleteOrderDetails Procedure
CREATE PROCEDURE DeleteOrderDetails
    @SalesOrderID INT,
    @ProductID INT
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Sales.SalesOrderDetail
        WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID
    )
    BEGIN
        PRINT 'Invalid parameters';
        RETURN -1;
    END

    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID;
END;
GO


-- =====================================
-- FUNCTIONS
-- =====================================

-- MM/DD/YYYY Format
CREATE FUNCTION fnFormatDate_MMDDYYYY (@date DATETIME)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN CONVERT(VARCHAR(10), @date, 101);
END;
GO

-- YYYYMMDD Format
DROP FUNCTION fnFormatDate_YYYYMMDD;
GO

CREATE FUNCTION fnFormatDate_YYYYMMDD (@date DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    RETURN CONVERT(VARCHAR(8), @date, 112);
END;
GO



-- =====================================
-- VIEWS
-- =====================================

-- vwCustomerSales.SalesOrderHeader View
CREATE VIEW vwCustomerSales_SalesOrderHeader AS
SELECT 
    p.FirstName + ' ' + p.LastName AS CustomerName,
    soh.SalesOrderID,
    soh.OrderDate,
    sod.ProductID,
    pr.Name AS ProductName,
    sod.OrderQty,
    sod.UnitPrice,
    (sod.OrderQty * sod.UnitPrice) AS Total
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product pr ON sod.ProductID = pr.ProductID;
GO


-- vwCustomerSales.SalesOrderHeaderYesterday View
CREATE VIEW vwCustomerSales_SalesOrderHeaderYesterday AS
SELECT * 
FROM vwCustomerSales_SalesOrderHeader
WHERE CAST(OrderDate AS DATE) = CAST(GETDATE() - 1 AS DATE);
GO


-- MyProduction.Product View
CREATE VIEW MyProduction_Product AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.Size,
    pv.StandardPrice,
    v.Name AS VendorName,
    pc.Name AS CategoryName
FROM Production.Product p
LEFT JOIN Purchasing.ProductVendor pv ON p.ProductID = pv.ProductID
LEFT JOIN Purchasing.Vendor v ON pv.BusinessEntityID = v.BusinessEntityID
LEFT JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
WHERE p.SellEndDate IS NULL; -- Assuming 'Discontinued' means not currently sold
GO

-- View: vwCustomerOrders
CREATE VIEW vwCustomerOrders AS
SELECT 
    c.CompanyName,
    soh.SalesOrderID,
    soh.OrderDate,
    sod.ProductID,
    p.Name AS ProductName,
    sod.OrderQty AS Quantity,
    sod.UnitPrice,
    sod.OrderQty * sod.UnitPrice AS TotalAmount
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID;
GO

-- View: vwCustomerOrders_Yesterday
CREATE VIEW vwCustomerOrders_Yesterday AS
SELECT * FROM vwCustomerOrders
WHERE CAST(OrderDate AS DATE) = CAST(GETDATE() - 1 AS DATE);
GO

-- View: MyProducts
CREATE VIEW MyProducts AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.QuantityPerUnit,
    p.UnitPrice,
    s.CompanyName AS SupplierCompany,
    c.Name AS CategoryName
FROM Production.Product p
JOIN Suppliers s ON p.SupplierID = s.SupplierID
JOIN Categories c ON p.CategoryID = c.CategoryID
WHERE p.Discontinued = 0;
GO

-- =====================================
-- TRIGGERS
-- =====================================

-- Trigger: Instead of Delete on Orders
CREATE TRIGGER trg_InsteadOfDelete_Orders
ON Sales.SalesOrderHeader
INSTEAD OF DELETE
AS
BEGIN
    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM DELETED);

    DELETE FROM Sales.SalesOrderHeader
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM DELETED);
END;
GO

-- Trigger: Check stock before insert
CREATE TRIGGER trg_CheckStock_BeforeInsert
ON Sales.SalesOrderDetail
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @ProductID INT, @Qty INT, @Stock INT;

    SELECT TOP 1 @ProductID = ProductID, @Qty = OrderQty
    FROM INSERTED;

    SELECT @Stock = UnitsInStock
    FROM Production.Product
    WHERE ProductID = @ProductID;

    IF @Stock IS NULL OR @Stock < @Qty
    BEGIN
        PRINT 'Order cannot be placed. Not enough stock.';
        RETURN;
    END

    -- If enough stock, insert and update
    INSERT INTO Sales.SalesOrderDetail
    SELECT * FROM INSERTED;

    UPDATE Production.Product
    SET UnitsInStock = UnitsInStock - @Qty
    WHERE ProductID = @ProductID;
END;
GO

-- Instead Of Delete Trigger on Sales.SalesOrderHeader
CREATE TRIGGER trg_InsteadOfDeleteOrder
ON Sales.SalesOrderHeader
INSTEAD OF DELETE
AS
BEGIN
    -- First delete related SalesOrderDetail records
    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM DELETED);

    -- Then delete from SalesOrderHeader
    DELETE FROM Sales.SalesOrderHeader
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM DELETED);
END;
GO

-- Trigger on Insert to Check Stock
CREATE TRIGGER trg_CheckStockOnInsert
ON Sales.SalesOrderDetail
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @ProductID INT, @Qty INT, @Stock INT, @SalesOrderID INT

    SELECT TOP 1 
        @ProductID = ProductID,
        @Qty = OrderQty,
        @SalesOrderID = SalesOrderID
    FROM INSERTED;

    SELECT @Stock = SafetyStockLevel
    FROM Production.Product
    WHERE ProductID = @ProductID;

    IF @Stock < @Qty
    BEGIN
        PRINT 'Order could not be filled due to insufficient stock.';
        RETURN;
    END

    -- Insert only non-IDENTITY columns (do NOT insert SalesOrderDetailID)
    INSERT INTO Sales.SalesOrderDetail (
        SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, rowguid, ModifiedDate
    )
    SELECT 
        SalesOrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, rowguid, ModifiedDate
    FROM INSERTED;

    -- Update stock
    UPDATE Production.Product
    SET SafetyStockLevel = SafetyStockLevel - @Qty
    WHERE ProductID = @ProductID;
END;
GO

==========================================================
--Sample Data for testing
==========================================================

-- Categories
INSERT INTO Categories (CategoryID, CategoryName)
VALUES (1, 'Beverages'), (2, 'Condiments');

-- Suppliers
INSERT INTO Suppliers (SupplierID, CompanyName)
VALUES (1, 'Fresh Foods Ltd'), (2, 'Spice World Inc');

-- Customers
INSERT INTO Customers (CustomerID, CompanyName)
VALUES ('C001', 'Alpha Corp'), ('C002', 'Beta Ltd');

-- Products
INSERT INTO Products (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock, ReorderLevel, Discontinued)
VALUES 
(101, 'Green Tea', 1, 1, '10 boxes x 20 bags', 15.00, 100, 20, 0),
(102, 'Hot Sauce', 2, 2, '24 - 8 oz bottles', 5.00, 50, 10, 0);

-- Orders
INSERT INTO Orders (OrderID, CustomerID, OrderDate)
VALUES 
(201, 'C001', GETDATE()),
(202, 'C002', DATEADD(DAY, -1, GETDATE())); -- yesterday's order

-- Order Details
INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
VALUES 
(201, 101, 15.00, 5, 0.1),
(202, 102, 5.00, 2, 0);


=================================================================
--Table formation
=================================================================

-- Categories Table
CREATE TABLE Categories (
    CategoryID INT PRIMARY KEY,
    CategoryName NVARCHAR(50) NOT NULL
);

-- Suppliers Table
CREATE TABLE Suppliers (
    SupplierID INT PRIMARY KEY,
    CompanyName NVARCHAR(100) NOT NULL
);

-- Customers Table
CREATE TABLE Customers (
    CustomerID NVARCHAR(10) PRIMARY KEY,
    CompanyName NVARCHAR(100) NOT NULL
);

-- Products Table
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    SupplierID INT FOREIGN KEY REFERENCES Suppliers(SupplierID),
    CategoryID INT FOREIGN KEY REFERENCES Categories(CategoryID),
    QuantityPerUnit NVARCHAR(50),
    UnitPrice DECIMAL(10, 2),
    UnitsInStock INT,
    ReorderLevel INT,
    Discontinued BIT
);

-- Orders Table
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID NVARCHAR(10) FOREIGN KEY REFERENCES Customers(CustomerID),
    OrderDate DATETIME
);

-- Order Details Table
CREATE TABLE [Order Details] (
    OrderID INT,
    ProductID INT,
    UnitPrice DECIMAL(10, 2),
    Quantity INT,
    Discount DECIMAL(4, 2),
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
