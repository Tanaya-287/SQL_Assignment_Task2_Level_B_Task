# SQL_Assignment_Task2_Level_B_Task

# SQL Server Procedures, Functions, and Views 📊

> ✅ This task was assigned by **Celebal Technologies** as part of the SQL Internship Program.

This project demonstrates the implementation of **Stored Procedures**, **Scalar Functions**, and **Views** in SQL Server, using the AdventureWorks or Northwind-style database schema. The task includes real-world operations such as inserting, updating, deleting, and retrieving order details along with formatting dates and creating reusable views.



## 🛠 Stored Procedures

### 1. `InsertOrderDetails`
- Inserts a new order detail entry.
- Auto-fetches `UnitPrice` from `Products` if not provided.
- Sets default `Discount = 0`.
- Checks and updates inventory stock.
- Aborts if not enough stock.
- Warns if stock drops below reorder level.

### 2. `UpdateOrderDetails`
- Updates order detail with optional values.
- Retains original values if inputs are `NULL`.
- Adjusts inventory stock accordingly.

### 3. `GetOrderDetails`
- Displays all details for a given `OrderID`.
- Returns an error message and exits if order does not exist.

### 4. `DeleteOrderDetails`
- Deletes a specific product from an order.
- Validates existence before deletion.
- Returns error message and code if invalid.

---

## 🧮 User-Defined Functions

### 1. `FormatDate_MMDDYYYY(@Date)`
- Returns date in `MM/DD/YYYY` format.

### 2. `FormatDate_YYYYMMDD(@Date)`
- Returns date in `YYYYMMDD` format.

---

## 🔎 Views

### `vwCustomerOrders`
- Combines data from:
  - `Customers`
  - `Orders`
  - `Order Details`
  - `Products`
- Shows: `CompanyName`, `OrderID`, `OrderDate`, `ProductID`, `ProductName`, `Quantity`, `UnitPrice`.

---

## ▶️ Usage Instructions

1. Restore the **AdventureWorks** or **Northwind** database in SQL Server.
2. Execute the scripts from the provided `.sql` file in SQL Server Management Studio (SSMS).
3. Test stored procedures and functions with sample data.
4. Query the view to validate output.

---

## 🎓 Credits

This assignment was completed as part of the **Celebal Technologies Internship Program** under the SQL domain.  
It includes practical exercises involving:
- Stored procedures
- Views and functions
- Business logic for order and inventory management

---

## 📝 License

This project is shared under the [MIT License](LICENSE).

---

