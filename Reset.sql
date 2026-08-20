USE msdb;
GO

-- Delete Full Backup Job
IF EXISTS (
    SELECT 1
    FROM dbo.sysjobs
    WHERE name = N'SmartBankDB - Full Backup'
)
BEGIN
    EXEC dbo.sp_delete_job
        @job_name = N'SmartBankDB - Full Backup';
END
GO

-- Delete Differential Backup Job
IF EXISTS (
    SELECT 1
    FROM dbo.sysjobs
    WHERE name = N'SmartBankDB - Differential Backup'
)
BEGIN
    EXEC dbo.sp_delete_job
        @job_name = N'SmartBankDB - Differential Backup';
END
GO

-- Delete Transaction Log Backup Job
IF EXISTS (
    SELECT 1
    FROM dbo.sysjobs
    WHERE name = N'SmartBankDB - Transaction Log Backup'
)
BEGIN
    EXEC dbo.sp_delete_job
        @job_name = N'SmartBankDB - Transaction Log Backup';
END
GO

USE msdb;
GO

DECLARE @ScheduleID INT;

DECLARE ScheduleCursor CURSOR FOR
SELECT schedule_id
FROM dbo.sysschedules
WHERE name LIKE N'SmartBankDB -%';

OPEN ScheduleCursor;

FETCH NEXT FROM ScheduleCursor INTO @ScheduleID;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.sp_delete_schedule
        @schedule_id = @ScheduleID;

    FETCH NEXT FROM ScheduleCursor INTO @ScheduleID;
END;

CLOSE ScheduleCursor;
DEALLOCATE ScheduleCursor;
GO

-- Drop SmartBankDB
USE master;
GO

IF DB_ID('SmartBankDB') IS NOT NULL
BEGIN
    ALTER DATABASE SmartBankDB
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE SmartBankDB;
END
GO

USE master;
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_audit_specifications
    WHERE name = 'SmartBankServerAudit'
)
BEGIN
    ALTER SERVER AUDIT SPECIFICATION SmartBankServerAudit
    WITH (STATE = OFF);

    DROP SERVER AUDIT SPECIFICATION SmartBankServerAudit;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_audits
    WHERE name = 'SmartBankAudit'
)
BEGIN
    ALTER SERVER AUDIT SmartBankAudit
    WITH (STATE = OFF);

    DROP SERVER AUDIT SmartBankAudit;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'BM0001'
)
    DROP LOGIN [BM0001];
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'BM0002'
)
    DROP LOGIN [BM0002];
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'BO0001'
)
    DROP LOGIN [BO0001];
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'BO0002'
)
    DROP LOGIN [BO0002];
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'C00001'
)
    DROP LOGIN [C00001];
GO

IF EXISTS (
    SELECT 1
    FROM sys.server_principals
    WHERE name = 'C00002'
)
    DROP LOGIN [C00002];
GO