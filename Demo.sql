USE SmartBankDB
GO

-- Insert initial data
INSERT INTO Staff (StaffID, StaffName, Position, Branch, Phone, Salary)
VALUES
('DB0001', 'Vinz Chan Yun Qi', 'DBA', 'HQ', '0123456789', 5000.00),
('BM0001', 'Devan Asokan', 'Bank Manager', 'Melaka', '0131112222', 8000.00),
('BM0002', 'Ng Cheng Xin', 'Bank Manager', 'Pahang', '0198765432', 7500.00),
('BO0001', 'Chin Xuan Han', 'Bank Officer', 'Melaka', '0142223333', 4500.00),
('BO0002', 'Ansel Yew', 'Bank Officer', 'Melaka', '0146663333', 4500.00);

-- Create Login
CREATE LOGIN [DB0001] WITH PASSWORD = 'DB0001!Pwd';
CREATE USER  [DB0001] FOR LOGIN [DB0001];
ALTER ROLE db_admin ADD MEMBER [DB0001];
GO

CREATE LOGIN [BM0001] WITH PASSWORD = 'BM0001PWD';
CREATE USER [BM0001] FOR LOGIN [BM0001];
ALTER ROLE bank_manager ADD MEMBER [BM0001];
GO

CREATE LOGIN [BM0002] WITH PASSWORD = 'BM0002!Pwd';
CREATE USER  [BM0002] FOR LOGIN [BM0002];
ALTER ROLE bank_manager ADD MEMBER [BM0001];
GO

CREATE LOGIN [BO0001] WITH PASSWORD = 'BO0001!Pwd';
CREATE USER  [BO0001] FOR LOGIN [BO0001];
ALTER ROLE bank_officer ADD MEMBER [BO0001];
GO

CREATE LOGIN [BO0002] WITH PASSWORD = 'BO0002!Pwd';
CREATE USER  [BO0002] FOR LOGIN [BO0002];
ALTER ROLE bank_officer ADD MEMBER [BO0002];
GO

------------------------------------------------------------------
-- Insert sample customer though bank officer
EXECUTE AS LOGIN = 'BO0001';

EXEC sp_InsertCustomer
    @CustomerName = 'Tan Wei Ling',
    @ICNumber     = '901231145566',
    @Phone        = '0123334444',
    @Address      = '12 Jalan Bunga, Melaka';

EXEC sp_InsertCustomer
    @CustomerName = 'Muhammad Ali bin Yusof',
    @ICNumber     = '880517125678',
    @Phone        = '0165556666',
    @Address      = '45 Jalan Ceria, Melaka';

select * from vw_MyStaffRecord
select * from vw_AllCustomerAccount -- (Need to insert account)
select * from vw_AllTransactions
select * from vw_StaffPublic
REVERT;

SELECT SUSER_NAME()
GO

-- Check generated customer details
SELECT CustomerID, CustomerName, ICNumber, Phone FROM Customer;
GO

----------------------------------------------------------------
CREATE LOGIN [C00001] WITH PASSWORD = 'C00001!Pwd';
CREATE USER  [C00001] FOR LOGIN [C00001];
ALTER ROLE customer ADD MEMBER [C00001];
GO

CREATE LOGIN [C00002] WITH PASSWORD = 'C00002!Pwd';
CREATE USER  [C00002] FOR LOGIN [C00002];
ALTER ROLE customer ADD MEMBER [C00002];
GO

EXECUTE AS LOGIN = 'BO0001';

EXEC sp_CreateAccount @CustomerID = 'C00001', @AccountType = 'Savings', @Pin = '123456';
EXEC sp_CreateAccount @CustomerID = 'C00002', @AccountType = 'Current', @Pin = '654321';

REVERT;
GO

-- Check generated account
SELECT AccountID, CustomerID, AccountType, Balance FROM Account;
GO

---------------------------------------------------------------
----------------------- Demonstration Start--------------------
---------------------------------------------------------------
------------- Confidentiality
-- vw_StaffPublic
EXECUTE AS LOGIN = 'C00001';

SELECT *
FROM vw_StaffPublic;

REVERT;
GO

-- vw_MyStaffRecord
EXECUTE AS LOGIN = 'BO0001'; -- Bank Officer

SELECT *
FROM dbo.vw_MyStaffRecord;

REVERT;
GO

EXECUTE AS LOGIN = 'BM0001'; -- Bank Manager

SELECT *
FROM dbo.vw_MyStaffRecord;

REVERT;
GO

EXECUTE AS LOGIN = 'DB0001'; -- DBA

SELECT *
FROM dbo.vw_MyStaffRecord;

REVERT;
GO

-- vw_AllBankOfficers
EXECUTE AS LOGIN = 'BM0001'; -- Bank Manager unmask officer salary

SELECT *
FROM vw_AllBankOfficers;

REVERT;
GO

-- vw_AllCustomerAccount
EXECUTE AS LOGIN = 'BM0001';

SELECT *
FROM vw_AllCustomerAccount;

REVERT;
GO

EXECUTE AS LOGIN = 'BO0001';

SELECT *
FROM vw_AllCustomerAccount;

REVERT;
GO

-- vw_AllTransactions
EXECUTE AS LOGIN = 'BM0001';

SELECT *
FROM vw_AllTransactions;

REVERT;
GO

EXECUTE AS LOGIN = 'BO0001';

SELECT *
FROM vw_AllTransactions;

REVERT;
GO

-- customer view their table
GRANT CONTROL ON CERTIFICATE::CustomerICCert TO customer;
GRANT CONTROL ON SYMMETRIC KEY::CustomerICKey TO customer;
GO

EXECUTE AS LOGIN = 'C00001';
OPEN SYMMETRIC KEY CustomerICKey
DECRYPTION BY CERTIFICATE CustomerICCert;

SELECT
    CustomerID,
    CustomerName,
    CONVERT(varchar(20), DECRYPTBYKEY(ICNumber)) AS ICNumber,
    Phone,
    Address
FROM Customer;

CLOSE SYMMETRIC KEY CustomerICKey;
REVERT;
GO

--------------------------------------------------------------------------------
------------- Confidentiality
-- Create and Alter Table
EXECUTE AS LOGIN = 'DB0001';
CREATE TABLE Payment(
	PaymentID varchar(6) primary key,
	PaymentType varchar(100),
);
REVERT;
SELECT SUSER_NAME()


SELECT * FROM Payment
GO

ALTER TABLE Payment ADD Amount decimal(12,2);
SELECT * FROM Payment;
GO

DROP TABLE Payment;
GO

-- sp_UpdateOwnStaffRecord
EXECUTE AS LOGIN = 'DB0001';

SELECT * FROM vw_MyStaffRecord;
EXEC sp_UpdateOwnStaffRecord -- Only StaffName, Branch, and Phone can change
    @StaffName = 'Vinz Updated',
    @Branch = 'HQ',
    @Phone = '0123456789';

REVERT;
GO

-- sp_InsertBankOfficer
EXECUTE AS LOGIN = 'BM0001';

SELECT * FROM vw_AllBankOfficers;

EXEC sp_InsertBankOfficer
    @StaffName = 'Demo Officer',
    @Branch = 'Melaka',
    @Phone = '0111111111',
    @Salary = 4000;

-- sp_UpdateBankOfficer
EXEC sp_UpdateBankOfficer
    @StaffID = 'BO0003',
    @Phone = '0149999999',
    @Salary = 6000;

-- sp_DeleteBankOfficer
EXEC sp_DeleteBankOfficer
    @StaffID = 'BO0003';

REVERT;

-- sp_InsertCustomer
EXECUTE AS LOGIN = 'BO0001'

SELECT * FROM vw_AllCustomerAccount

EXEC sp_InsertCustomer
    @CustomerName = 'Demo Customer',
    @ICNumber = '901010101010',
    @Phone = '0112223333',
    @Address = 'Demo Address';

-- sp_UpdateCustomer
EXEC sp_UpdateCustomer
    @CustomerID = 'C00003',
    @CustomerName = 'Demo Customer Updated',
    @Phone = '0183356762';

-- sp_DeleteCustomer
EXEC sp_DeleteCustomer
    @CustomerID = 'C00003';

-- sp_CreateAccount
EXEC sp_CreateAccount
    @CustomerID = 'C00002',
    @AccountType = 'Savings',
    @Pin = '666666';

REVERT;

-- sp_Deposit
EXECUTE AS LOGIN = 'C00002';

SELECT * FROM Account;

EXEC sp_Deposit
    @AccountID = 'A000000002',
    @Amount = 500;

-- sp_Withdraw
EXEC sp_Withdraw
    @AccountID = 'A000000002',
    @Amount = 10,
    @Pin = '654321';

-- sp_Transfer
EXEC sp_Transfer
    @AccountID = 'A000000002',
    @ToAccountID = 'A000000001',
    @Amount = 200,
    @Pin = '654321';
REVERT;

EXECUTE AS LOGIN = 'C00001';
SELECT * FROM Account;
REVERT;