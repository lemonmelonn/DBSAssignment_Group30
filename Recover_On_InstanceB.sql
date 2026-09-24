DROP CERTIFICATE SmartBankBackupCert;
GO
---------------------------- Pwd: Str0ng!MasterKeyPwd123

USE master;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'NewInstanceMasterKey@2026!';
GO

CREATE CERTIFICATE SmartBankBackupCert
FROM FILE = 'C:\Users\chanv\Desktop\SmartBankBackupCert.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\Users\chanv\Desktop\SmartBankBackupCert.pvk',
    DECRYPTION BY PASSWORD = 'CertificateExport@2026!'
);
GO

RESTORE DATABASE SmartBankDB_Test
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak'
WITH
    MOVE 'SmartBankDB'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.NEWMSSQLSERVER\MSSQL\DATA\SmartBankDB_Test.mdf',
    MOVE 'SmartBankDB_log'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.NEWMSSQLSERVER\MSSQL\DATA\SmartBankDB_Test_log.ldf',
    RECOVERY,
    STATS = 10;
GO

USE SmartBankDB_Test
SELECT * FROM TransactionRecord;
GO

USE master;
ALTER DATABASE SmartBankDB_Test
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
DROP DATABASE SmartBankDB_Test;
GO