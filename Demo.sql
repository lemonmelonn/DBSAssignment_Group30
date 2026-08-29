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
SELECT * FROM Customer;
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
------------- Integrity
-- Create and Alter Table
EXECUTE AS LOGIN = 'DB0001';
CREATE TABLE Payment(
	PaymentID varchar(6) primary key,
	PaymentType varchar(100),
);
REVERT;
GRANT SELECT ON dbo.Payment TO db_admin;

SELECT SUSER_NAME()

SELECT * FROM Payment
GO

ALTER TABLE Payment ADD Amount decimal(12,2);
SELECT * FROM Payment;
GO

DROP TABLE Payment;
GO
REVERT;


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
    @CustomerID = 'C00003'; -- cannot delete if the customer has at least one account due to Foreign Key dependency

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

-- audit server
USE master;
GO

SELECT * FROM sys.server_audits
WHERE name = 'SmartBankAudit';
GO

USE master;
GO

SELECT
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_name,
    schema_name,
    object_name,
    statement
FROM sys.fn_get_audit_file(
    'C:\SQLAssignment\SQLAudit\*.sqlaudit',
    DEFAULT,
    DEFAULT
)
WHERE database_name = 'SmartBankDB'
ORDER BY event_time DESC;
GO

-- Specified action for (view)
SELECT
    event_time,
    server_principal_name,
    database_name,
    schema_name,
    object_name,
    succeeded,
    statement
FROM sys.fn_get_audit_file(
    'C:\SQLAssignment\SQLAudit\*.sqlaudit',
    DEFAULT,
    DEFAULT
)
WHERE database_name = 'SmartBankDB'
  AND object_name IN
  (
      'vw_AllCustomerAccount',
      'vw_AllTransactions',
      'vw_AllBankOfficers'
  )
ORDER BY event_time DESC;

-- Customer Audit Table
USE SmartBankDB;
GO

SELECT * FROM AuditLog;
GO

-----------------------------------------------------------------------------
--------- Availability

-- Show schedule
USE msdb;
GO

SELECT
    j.name AS JobName,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS Status,
    h.message AS Message
FROM dbo.sysjobhistory AS h
JOIN dbo.sysjobs AS j ON h.job_id = j.job_id
WHERE j.name IN
(
    N'SmartBankDB - Full Backup',
    N'SmartBankDB - Differential Backup',
    N'SmartBankDB - Transaction Log Backup'
)
AND h.step_id = 0
ORDER BY RunDateTime DESC;
GO

USE msdb;
GO

SELECT TOP 10
    j.name AS JobName,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    h.step_id,
    h.step_name,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS Status,
    h.message
FROM dbo.sysjobhistory h
JOIN dbo.sysjobs j
    ON h.job_id = j.job_id
WHERE j.name IN (
    N'SmartBankDB - Full Backup',
    N'SmartBankDB - Differential Backup',
    N'SmartBankDB - Transaction Log Backup'
)
ORDER BY h.instance_id DESC;
GO

-- 1. Manual Fresh Full backup 
USE msdb;
GO

EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Full Backup';
GO

RESTORE HEADERONLY FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak'; -- Show backup file is encrypted
GO

-- 2. First test change
USE SmartBankDB;
GO
EXECUTE AS LOGIN = 'C00001';
SELECT * FROM TransactionRecord

EXEC sp_Deposit
    @AccountID = 'A000000001',
    @Amount = 50.00;

REVERT;
GO

-- 3. Manual Fresh Differential backup 
USE msdb;
GO

EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Differential Backup';
GO

-- 4. Second test change
USE SmartBankDB;
GO

EXECUTE AS LOGIN = 'C00001';

EXEC sp_Deposit
    @AccountID = 'A000000001',
    @Amount = 20.00;

REVERT;
GO

-- 5. Manual Log Transaction
USE msdb;
GO

EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Transaction Log Backup';
GO

USE SmartBankDB;
GO
SELECT * FROM TransactionRecord ORDER BY TransID;

-- 6. Demo Accidentally data deletion
Select GetDate()

DELETE FROM TransactionRecord
WHERE TransID = 2;
GO

SELECT * FROM TransactionRecord ORDER BY TransID;

-- 7. Immediately perform Tail-Log Backup
USE master;
GO

BACKUP LOG SmartBankDB
TO DISK =
'C:\SQLAssignment\SQLBackups\SmartBankDB_TailLog.trn'
WITH NO_TRUNCATE,
     INIT,
     COMPRESSION,
     ENCRYPTION
     (
         ALGORITHM = AES_256,
         SERVER CERTIFICATE = SmartBankBackupCert
     ),
     NAME = 'SmartBankDB-Tail Log Backup',
     DESCRIPTION = 'Emergency tail-log backup for point-in-time recovery';
GO

-- 8. Restore to a NEW database
USE master;
GO

IF DB_ID('SmartBankDB_Recovery') IS NOT NULL
BEGIN
    ALTER DATABASE SmartBankDB_Recovery
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE SmartBankDB_Recovery;
END
GO

-- 8.1 Restore Full backup
RESTORE DATABASE SmartBankDB_Recovery
FROM DISK =
'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak'
WITH
    MOVE 'SmartBankDB'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery.mdf',

    MOVE 'SmartBankDB_log'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery_log.ldf',

    NORECOVERY,
    STATS = 10;
GO

-- 8.2 Restore Differential
RESTORE DATABASE SmartBankDB_Recovery
FROM DISK =
'C:\SQLAssignment\SQLBackups\SmartBankDB_Diff.bak'
WITH NORECOVERY,
     STATS = 10;
GO

-- 8.3 Restore regular LOG
RESTORE LOG SmartBankDB_Recovery
FROM DISK =
'C:\SQLAssignment\SQLBackups\SmartBankDB_Log.trn'
WITH NORECOVERY,
     STATS = 10;
GO

-- 8.4 Restore TAIL LOG to the point before deletion
RESTORE LOG SmartBankDB_Recovery
FROM DISK =
'C:\SQLAssignment\SQLBackups\SmartBankDB_TailLog.trn'
WITH
    STOPAT = '2026-08-29 14:38:34.940',
    RECOVERY,
    STATS = 10;
GO

USE SmartBankDB_Recovery;
GO

SELECT *
FROM TransactionRecord
ORDER BY TransID;
GO

-- 9. Export backup certificate

USE master;
GO

BACKUP CERTIFICATE SmartBankBackupCert
TO FILE = 'C:\SQLAssignment\SQLBackups\SmartBankBackupCert.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\SQLAssignment\SQLBackups\SmartBankBackupCert.pvk',
    ENCRYPTION BY PASSWORD = 'CertificateExport@2026!'
);
GO

-- 10. Recover to SmartBank_DB
-- Disconnet all uses
USE master
ALTER DATABASE SmartBankDB
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO
-- Rename damaged database
ALTER DATABASE SmartBankDB
MODIFY NAME = SmartBankDB_Damaged;
GO
-- Rename recover database
ALTER DATABASE SmartBankDB_Recovery
MODIFY NAME = SmartBankDB;
GO
-- Set to multi user
ALTER DATABASE SmartBankDB
SET MULTI_USER;
GO

USE SmartBankDB
SELECT * FROM TransactionRecord ORDER BY TransID;
GO

USE master;
GO