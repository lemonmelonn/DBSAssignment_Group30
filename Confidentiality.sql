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
	ICNumber varbinary(256),
	Phone varchar(20),
	Address varchar(200)
);
Create Table Account(
	AccountID varchar(10) primary key,
	CustomerID varchar(6),
	AccountType varchar(20),
	Balance decimal(12,2),
	PinHash varbinary(64),
	PinSalt varbinary(16),

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


-- Create Role
CREATE ROLE db_admin;
CREATE ROLE bank_manager;
CREATE ROLE bank_officer;
CREATE ROLE customer;


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

-- 3. View all customer accounts
CREATE VIEW vw_AllCustomerAccount
AS
SELECT c.CustomerID, c.CustomerName, a.AccountID, a.AccountType, a.Balance FROM Customer c
JOIN Account a on c.CustomerID = a.CustomerID;
GO

-- 4. View all transactions
CREATE VIEW vw_AllTransactions
AS
SELECT * FROM TransactionRecord;
GO

-- Grant permissions to the bank_manager role
GRANT SELECT ON vw_MyStaffRecord TO bank_manager;
GRANT SELECT ON vw_AllBankOfficers TO bank_manager;
GRANT SELECT ON vw_AllCustomerAccount TO bank_manager;
GRANT SELECT ON vw_AllTransactions TO bank_manager;

------------- Bank Officers Permissions -------------
-- 1. View only their own record (reuse)
GRANT SELECT ON vw_MyStaffRecord TO bank_officer;
GO

-- 2. View all customer accounts
GRANT SELECT ON vw_AllCustomerAccount TO bank_officer;
GO

-- 3. View all transactions
GRANT SELECT ON vw_AllTransactions TO bank_officer;
GO

------------- Database Admin (DBA) permissions -------------
-- 1. View only their own record (reuse)
GRANT SELECT ON vw_MyStaffRecord TO db_admin;
GO


------------- Customer Permissions -------------
-- 1. View only their own record
-- Security Policy
CREATE SCHEMA Security;
GO
-- Customer
CREATE FUNCTION Security.fn_CustomerAccessPredicate(@CustomerID varchar(6))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_result
WHERE
    IS_SRVROLEMEMBER('sysadmin') = 1
    OR IS_MEMBER('bank_manager') = 1
    OR IS_MEMBER('bank_officer') = 1
    OR @CustomerID = SUSER_SNAME();
GO

CREATE SECURITY POLICY Security.CustomerFilter
ADD FILTER PREDICATE Security.fn_CustomerAccessPredicate(CustomerID)
ON dbo.Customer
WITH (STATE = ON);
GO

-- Account
CREATE FUNCTION Security.fn_AccountAccessPredicate(@CustomerID varchar(6))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_result
WHERE
    IS_SRVROLEMEMBER('sysadmin') = 1
    OR IS_MEMBER('bank_manager') = 1
    OR IS_MEMBER('bank_officer') = 1
    OR @CustomerID = SUSER_SNAME();
GO

CREATE SECURITY POLICY Security.AccountFilter
ADD FILTER PREDICATE Security.fn_AccountAccessPredicate(CustomerID)
ON dbo.Account
WITH (STATE = ON);
GO

--2. View only their own transactions
-- TransactionRecord
CREATE FUNCTION Security.fn_TransactionAccessPredicate(@AccountID varchar(10))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_result
WHERE
    IS_SRVROLEMEMBER('sysadmin') = 1
    OR IS_MEMBER('bank_manager') = 1
    OR IS_MEMBER('bank_officer') = 1
    OR EXISTS (
        SELECT 1 FROM dbo.Account a
        WHERE a.AccountID = @AccountID AND a.CustomerID = SUSER_SNAME()
    );
GO

CREATE SECURITY POLICY Security.TransactionFilter
ADD FILTER PREDICATE Security.fn_TransactionAccessPredicate(AccountID)
ON dbo.TransactionRecord
WITH (STATE = ON);
GO

GRANT SELECT ON dbo.Customer TO customer;
GRANT SELECT ON dbo.Account TO customer;
GRANT SELECT ON dbo.TransactionRecord TO customer;

-----------------------------------------------------------------------------------------
--- Data Protection
--  Dynamic Data Masking (DDM)
ALTER TABLE Customer
ALTER COLUMN Phone varchar(20) MASKED WITH (FUNCTION = 'partial(2,"XXXXX",2)') NULL;
GO

ALTER TABLE Staff
ALTER COLUMN Salary decimal(10,2) MASKED WITH (FUNCTION = 'random(1000, 9999)') NULL;
GO

GRANT UNMASK ON Staff(Salary) TO bank_manager;


-- Server level audit
USE master;
GO

CREATE SERVER AUDIT SmartBankAudit
TO FILE (FILEPATH = 'C:\SQLAssignment\SQLAudit');
GO
AlTER SERVER AUDIT SmartBankAudit WITH (STATE = ON);
GO

USE SmartBankDB;
GO
CREATE DATABASE AUDIT SPECIFICATION SmartBankReadAudit
FOR SERVER AUDIT SmartBankAudit
ADD (SELECT ON OBJECT::dbo.vw_AllTransactions BY bank_manager, bank_officer),
ADD (SELECT ON OBJECT::dbo.vw_AllCustomerAccount BY bank_manager, bank_officer),
ADD (SELECT ON OBJECT::dbo.vw_AllBankOfficers BY bank_manager)
WITH (STATE = ON);
GO

-- Encrypt Server
/*
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng!ServerMasterKeyPwd123';
GO
CREATE CERTIFICATE SmartBankTDECert WITH SUBJECT = 'SmartBankDB TDE Certificate';
GO

USE SmartBankDB;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE SmartBankTDECert;
GO
ALTER DATABASE SmartBankDB SET ENCRYPTION ON;
GO
*/
