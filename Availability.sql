---------------------------------------------------------------
-- SET DATABASE TO FULL RECOVERY MODEL
---------------------------------------------------------------

USE master;
GO

ALTER DATABASE SmartBankDB
SET RECOVERY FULL;
GO

---------------------------------------------------------------
-- Backup Encryption setup
---------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    PRINT 'Creating Database Master Key...';

    CREATE MASTER KEY
        ENCRYPTION BY PASSWORD = 'SmartBank@2026SecureKey!';

    PRINT 'Database Master Key created.';
END
ELSE
BEGIN
    PRINT 'Database Master Key already exists. Skipping creation.';
END
GO

---------------------------------------------------------------
-- 1. CREATE FULL BACKUP JOB
--    Schedule: Every Sunday at 1:00 AM
---------------------------------------------------------------

USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'SmartBankDB - Full Backup',
    @enabled = 1,
    @description = N'Weekly full backup of SmartBankDB.';
GO


EXEC dbo.sp_add_jobstep
    @job_name = N'SmartBankDB - Full Backup',
    @step_name = N'Run Full Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
BACKUP DATABASE SmartBankDB
TO DISK = ''C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak''
WITH INIT,
     COMPRESSION,
     ENCRYPTION (
         ALGORITHM = AES_256,
         SERVER CERTIFICATE = SmartBankBackupCert
     ),
     NAME = ''SmartBankDB-Full'',
     DESCRIPTION = ''Weekly encrypted full backup of SmartBankDB'';
';
GO


EXEC dbo.sp_add_schedule
    @schedule_name = N'SmartBankDB - Weekly Full Backup',
    @enabled = 1,
    @freq_type = 8,                  -- Weekly
    @freq_interval = 1,              -- Sunday
    @freq_recurrence_factor = 1,     -- Every 1 week
    @active_start_time = 010000;     -- 01:00:00
GO


EXEC dbo.sp_attach_schedule
    @job_name = N'SmartBankDB - Full Backup',
    @schedule_name = N'SmartBankDB - Weekly Full Backup';
GO


EXEC dbo.sp_add_jobserver
    @job_name = N'SmartBankDB - Full Backup';
GO


---------------------------------------------------------------
-- 2. CREATE DIFFERENTIAL BACKUP JOB
--    Schedule: Monday-Saturday at 1:00 AM
---------------------------------------------------------------

EXEC dbo.sp_add_job
    @job_name = N'SmartBankDB - Differential Backup',
    @enabled = 1,
    @description = N'Daily differential backup of SmartBankDB.';
GO


EXEC dbo.sp_add_jobstep
    @job_name = N'SmartBankDB - Differential Backup',
    @step_name = N'Run Differential Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
BACKUP DATABASE SmartBankDB
TO DISK = ''C:\SQLAssignment\SQLBackups\SmartBankDB_Diff.bak''
WITH DIFFERENTIAL,
     INIT,
     COMPRESSION,
     ENCRYPTION (
         ALGORITHM = AES_256,
         SERVER CERTIFICATE = SmartBankBackupCert
     ),
     NAME = ''SmartBankDB-Differential'',
     DESCRIPTION = ''Daily encrypted differential backup of SmartBankDB'';
';
GO


EXEC dbo.sp_add_schedule
    @schedule_name = N'SmartBankDB - Daily Differential Backup',
    @enabled = 1,
    @freq_type = 8,                  -- Weekly
    @freq_interval = 126,            -- Monday-Saturday
    @freq_recurrence_factor = 1,     -- Every week
    @active_start_time = 010000;     -- 01:00:00
GO


EXEC dbo.sp_attach_schedule
    @job_name = N'SmartBankDB - Differential Backup',
    @schedule_name = N'SmartBankDB - Daily Differential Backup';
GO


EXEC dbo.sp_add_jobserver
    @job_name = N'SmartBankDB - Differential Backup';
GO


---------------------------------------------------------------
-- 3. CREATE TRANSACTION LOG BACKUP JOB
--    Schedule: Every 15 minutes
---------------------------------------------------------------

EXEC dbo.sp_add_job
    @job_name = N'SmartBankDB - Transaction Log Backup',
    @enabled = 1,
    @description = N'Transaction log backup every 15 minutes to support a 15-minute RPO.';
GO


EXEC dbo.sp_add_jobstep
    @job_name = N'SmartBankDB - Transaction Log Backup',
    @step_name = N'Run Transaction Log Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
BACKUP LOG SmartBankDB
TO DISK = ''C:\SQLAssignment\SQLBackups\SmartBankDB_Log.trn''
WITH FORMAT,
     INIT,
     COMPRESSION,
     ENCRYPTION (
         ALGORITHM = AES_256,
         SERVER CERTIFICATE = SmartBankBackupCert
     ),
     NAME = ''SmartBankDB-Transaction Log'',
     DESCRIPTION = ''Encrypted transaction log backup of SmartBankDB'';
';
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'SmartBankDB - Every 15 Minutes',
    @enabled = 1,
    @freq_type = 4,                  -- Daily
    @freq_interval = 1,              -- Every day
    @freq_subday_type = 4,           -- Minutes
    @freq_subday_interval = 15,      -- Every 15 minutes
    @active_start_time = 000000,      -- 00:00:00
    @active_end_time = 235959;        -- 23:59:59
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'SmartBankDB - Transaction Log Backup',
    @schedule_name = N'SmartBankDB - Every 15 Minutes';
GO


EXEC dbo.sp_add_jobserver
    @job_name = N'SmartBankDB - Transaction Log Backup';
GO

--- Verify backup creation
USE msdb;
GO

SELECT
    name AS JobName,
    enabled,
    description
FROM dbo.sysjobs
WHERE name LIKE 'SmartBankDB -%';
GO

SELECT
    j.name AS JobName,
    s.name AS ScheduleName,
    s.enabled
FROM dbo.sysjobs AS j
JOIN dbo.sysjobschedules AS js
    ON j.job_id = js.job_id
JOIN dbo.sysschedules AS s
    ON js.schedule_id = s.schedule_id
WHERE j.name LIKE 'SmartBankDB -%';
GO

SELECT
    schedule_id,
    name,
    enabled
FROM dbo.sysschedules
WHERE name LIKE 'SmartBankDB -%';
GO


-- Recovery Demo
------------------------------------------------------
USE SmartBankDB
select * from TransactionRecord

-- 1. Full Backup
USE msdb;
GO
EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Full Backup';
GO

-- Check whether backup is encrypted
RESTORE HEADERONLY
    FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak';
GO

-- 2. Test change
USE SmartBankDB;
GO

EXECUTE AS LOGIN = 'C00001';
EXEC sp_Deposit @AccountID = 'A000000001', @Amount = 50.00;
REVERT;
GO

-- 3. Differential 
USE msdb;
GO
EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Differential Backup';
GO

-- 4. Test another change
USE SmartBankDB;
GO

EXECUTE AS LOGIN = 'C00001';
EXEC sp_Deposit @AccountID = 'A000000001', @Amount = 20.00;
REVERT;
GO

-- 5. Log Backup
USE msdb;
GO
EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Transaction Log Backup';
GO

USE SmartBankDB;
Select * From TransactionRecord;
GO

-- 6. Simulate data loss
Select GetDate()

USE SmartBankDB;
GO
DELETE FROM TransactionRecord
WHERE TransID = 1

Select * From TransactionRecord;
GO

-- 7. Capture final portion of the transaction log
USE master;
GO

BACKUP LOG SmartBankDB
TO DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_TailLog.trn'
WITH NO_TRUNCATE,
     INIT,
     COMPRESSION,
     ENCRYPTION (
         ALGORITHM = AES_256,
         SERVER CERTIFICATE = SmartBankBackupCert
     ),
     NAME = 'SmartBankDB-Tail Log Backup',
     DESCRIPTION = 'Emergency tail-log backup for point-in-time recovery';
GO

-- Verify
RESTORE HEADERONLY
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_TailLog.trn';
GO

-- 7.  Restore
RESTORE DATABASE SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak'
WITH
    MOVE 'SmartBankDB'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery_test2.mdf',

    MOVE 'SmartBankDB_log'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery_test2_log.ldf',

    NORECOVERY;
GO

RESTORE DATABASE SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Diff.bak'
WITH NORECOVERY;
GO

RESTORE LOG SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Log.trn'
WITH NORECOVERY;
GO

RESTORE LOG SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_TailLog.trn'
WITH
    STOPAT = '2026-08-21 09:37:03.583', -- (Change to record date)
    RECOVERY,
    STATS = 10;
GO
---
USE master;
GO

SELECT
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalFileName,
    physical_name
FROM sys.master_files
WHERE physical_name LIKE '%SmartBankDB_Recovery%';
GO

-- 8. Check Restore Database (Should be the value when transaction log backup activate)
USE SmartBankDB_Recovery;
GO

SELECT * FROM TransactionRecord;
GO

-- 9. Recover to SmartBank_DB
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
-- Verify
Use SmartBankDB
Select * From Account

USE master;
GO


--------------------------------------------------------------------------
-- Check backup activity
USE msdb;
GO

SELECT TOP 20
    j.name AS JobName,
    h.step_id,
    h.step_name,
    h.run_date,
    h.run_time,
    h.run_status,
    h.message
FROM dbo.sysjobhistory AS h
INNER JOIN dbo.sysjobs AS j
    ON h.job_id = j.job_id
WHERE j.name = N'SmartBankDB - Transaction Log Backup'
ORDER BY
    h.instance_id DESC;
GO

USE msdb;
GO

SELECT TOP 50
    j.name AS JobName,

    msdb.dbo.agent_datetime(
        h.run_date,
        h.run_time
    ) AS RunDateTime,

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
JOIN dbo.sysjobs AS j
    ON h.job_id = j.job_id

WHERE j.name IN (
    N'SmartBankDB - Full Backup',
    N'SmartBankDB - Differential Backup',
    N'SmartBankDB - Transaction Log Backup'
)
AND h.step_id = 0

ORDER BY
    h.run_date DESC,
    h.run_time DESC;
GO