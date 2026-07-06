-- Appendix 1
Create Database SmartBankDB;
GO
Use SmartBankDB;
GO

Create Table Staff(
StaffID varchar(6) primary key,
StaffName varchar(100),
Position varchar(20),
Branch varchar(50),
Phone varchar(20),
Salary decimal(10,2)
);
Create Table Customer(
CustomerID varchar(6) primary key,
CustomerName varchar(100),
ICNumber varchar(20),
Phone varchar(20),
Address varchar(200)
);
Create Table Account(
AccountID varchar(10) primary key,
CustomerID varchar(6),
AccountType varchar(20),
Balance decimal(12,2)
);
Create Table TransactionRecord(
TransID int identity primary key,
AccountID varchar(10),
TransDate datetime,
Amount decimal(12,2),
TransactionType varchar(20)
);

-- Foreign Key connections



-- Create Role
CREATE ROLE db_admin;
CREATE ROLE bank_manager;
CREATE ROLE bank_officer;
CREATE ROLE customer;

-- All user can access this view
CREATE VIEW vw_StaffPublic
AS
SELECT StaffName, Phone From Staff;

-- Grant to all users
GRANT SELECT ON vw_StaffPublic TO db_admin, bank_manager, bank_officer, customer;

------------- Bank Manager Permissions -------------
-- 1. View their own record
CREATE VIEW vw_MyStaffRecord
AS
SELECT * FROM Staff
WHERE StaffID = SUSER_SNAME();
GO

-- 2. View all staff (Bank Officers record)
CREATE VIEW vw_AllBankOfficers
AS
SELECT * FROM Staff
WHERE Position = 'Bank Officer';
GO

-- 3. View all customer accounts
CREATE VIEW vw_AllCustomer
AS
SELECT * FROM Customer;
GO

-- 4. View all transactions
CREATE VIEW 
AS
SELECT * FROM TransactionRecord;
GO

-- Grant permissions to the bank_manager role
GRANT SELECT ON vw_MyStaffRecord TO bank_manager;
GRANT SELECT ON vw_AllBankOfficers TO bank_manager;
GRANT SELECT ON vw_AllCustomer TO bank_manager;
GRANT SELECT ON vw_AllTransactions TO bank_manager;

------------- Bank Officers Permissions -------------
-- 1. View only their own record (reuse)
GRANT SELECT ON vw_MyStaffRecord TO bank_officer;

-- 2. View all customer accounts
CREATE VIEW vw_CustomerAccount
AS
SELECT * FROM Customer;
GO

-- 3. View all transactions
GRANT SELECT ON vw_AllTransactions TO bank_officer;

------------- Database Admin (DBA) permissions -------------
-- 1. View only their own record (reuse)
GRANT SELECT ON vw_MyStaffRecord TO db_admin;

------------- Customer Permissions -------------
-- 1. View only their own record
CREATE VIEW vw_MyCustomerAccounts
AS
SELECT * FROM Customer
WHERE CustomerID = SUSER_SNAME();

--2. View only their own transactions
CREATE VIEW vw_MyTransactionRecords
AS
SELECT * FROM TransactionRecord
WHERE CustomerID = SUSER_NAME();
