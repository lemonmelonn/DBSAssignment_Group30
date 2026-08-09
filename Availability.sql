/*

--------- FULL backup ---------
BACKUP DATABASE SmartBankDB
TO DISK = ''C:\SQLBackups\SmartBankDB_Full_'' 
    + REPLACE(CONVERT(varchar(20), GETDATE(), 112), '' '', '''') 
    + ''.bak''
WITH INIT, NAME = ''SmartBankDB-Full'';';


--------- DIFFERENTIAL backup ---------
BACKUP DATABASE SmartBankDB
TO DISK = ''C:\SQLBackups\SmartBankDB_Diff_'' 
    + REPLACE(CONVERT(varchar(20), GETDATE(), 112), '' '', '''') 
    + ''.bak''
WITH DIFFERENTIAL, INIT, NAME = ''SmartBankDB-Differential'';';


--------- Transaction Log Backup ---------
BACKUP LOG SmartBankDB
TO DISK = ''C:\SQLBackups\SmartBankDB_Log_'' 
    + REPLACE(CONVERT(varchar(20), GETDATE(), 112), '' '', '''')
    + ''_'' + REPLACE(CONVERT(varchar(8), GETDATE(), 108), '':'', '''')
    + ''.trn''
WITH NOINIT, NAME = ''SmartBankDB-Log'';';

*/

--- Encryp Backup


---- Drop Database !!!
USE master
GO

ALTER DATABASE SmartBankDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'SmartBankReadAudit')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION SmartBankReadAudit WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION SmartBankReadAudit;
END
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SmartBankDB')
    DROP DATABASE SmartBankDB;
GO

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'SmartBankServerAudit')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION SmartBankServerAudit WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION SmartBankServerAudit;
END
GO

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'SmartBankAudit')
BEGIN
    ALTER SERVER AUDIT SmartBankAudit WITH (STATE = OFF);
    DROP SERVER AUDIT SmartBankAudit;
END
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'BM00001')
    DROP LOGIN [BM001];
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'BO00001')
    DROP LOGIN [BO00001];
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'C00001')
    DROP LOGIN [C00001];
GO
