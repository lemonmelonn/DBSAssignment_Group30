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
	Balance decimal(12,2),
	Pin char(6)

	FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
);
Create Table TransactionRecord(
	TransID int identity primary key,
	AccountID varchar(10),
	TransDate datetime,
	Amount decimal(12,2),
	TransactionType varchar(20),

	FOREIGN KEY (AccountID) REFERENCES Account(AccountID)
);

-- Foreign Key connections



-- Create Role
CREATE ROLE db_admin;
CREATE ROLE bank_manager;
CREATE ROLE bank_officer;
CREATE ROLE customer;

-- Create Login
CREATE LOGIN [BM00001] WITH PASSWORD = 'BM00001PWD';
CREATE USER [BM00001] FOR LOGIN [BM00001];
ALTER ROLE bank_manager ADD MEMBER [BM00001];
GO

CREATE LOGIN [BO00001] WITH PASSWORD = 'BO00001PWD';
CREATE USER  [BO00001] FOR LOGIN [BO00001];
ALTER ROLE bank_officer ADD MEMBER [BO00001];
GO

CREATE LOGIN [C00001] WITH PASSWORD = 'C00001PWD';
CREATE USER  [C00001] FOR LOGIN [C00001];
ALTER ROLE customer ADD MEMBER [C00001];
GO

-- Test as Bank Manager
EXECUTE AS LOGIN = 'BM00001';
SELECT * FROM vw_MyStaffRecord;   -- should return only BM001's row
SELECT * FROM Staff;  -- should fail (denied)
SELECT SUSER_SNAME()
REVERT;
GO

EXECUTE AS LOGIN = 'C00001';
SELECT * FROM vw_MyStaffRecord;
REVERT;
GO

SELECT SUSER_NAMES()

-- All user can access this view
CREATE VIEW vw_StaffPublic
AS
SELECT StaffName, Phone From Staff;
GO

-- Grant to all users
GRANT SELECT ON vw_StaffPublic TO db_admin, bank_manager, bank_officer, customer;
GO

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

-- 3. View all customer accounts **(Need to join with account table?)
CREATE VIEW vw_AllCustomer
AS
SELECT * FROM Customer;
GO

-- 4. View all transactions
CREATE VIEW vw_AllTransactions
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
GO

-- 2. View all customer accounts
GRANT SELECT ON vw_AllCustomer TO bank_officer;

-- 3. View all transactions
GRANT SELECT ON vw_AllTransactions TO bank_officer;

------------- Database Admin (DBA) permissions -------------
-- 1. View only their own record (reuse)
GRANT SELECT ON vw_MyStaffRecord TO db_admin;
GO


------------- Customer Permissions -------------
-- 1. View only their own record
CREATE VIEW vw_MyCustomerAccounts
AS
SELECT * FROM Customer
WHERE CustomerID = SUSER_SNAME();
GO

--2. View only their own transactions
CREATE VIEW vw_MyTransactionRecords
AS
SELECT * FROM TransactionRecord t
JOIN Account a on t.AccountID = a.AccountID
WHERE a.CustomerID = SUSER_SNAME();
GO

GRANT SELECT ON vw_MyCustomerAccounts   TO customer;
GRANT SELECT ON vw_MyTransactionRecords TO customer;