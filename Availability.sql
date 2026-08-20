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
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SmartBank@2026SecureKey!';
GO

CREATE CERTIFICATE SmartBankBackupCert
WITH SUBJECT = 'Certificate for SmartBankDB Backup Encryption';
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
WITH INIT,
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
select * from Account

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

UPDATE Account
SET Balance = Balance + 10
WHERE AccountID = 'A000000001';
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

UPDATE Account
SET Balance = Balance + 30
WHERE AccountID = 'A000000001';
GO

-- 5. Log Backup
USE msdb;
GO
EXEC dbo.sp_start_job
    @job_name = N'SmartBankDB - Transaction Log Backup';
GO

-- 6. Simulate data loss
USE SmartBankDB;
GO

UPDATE Account
SET Balance = 0
WHERE AccountID = 'A000000001';
GO

SELECT AccountID, Balance
FROM Account
WHERE AccountID = 'A000000001';
GO

-- 7.  Restore
RESTORE DATABASE SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Full.bak'
WITH
    MOVE 'SmartBankDB'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery.mdf',

    MOVE 'SmartBankDB_log'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\SmartBankDB_Recovery_log.ldf',

    NORECOVERY;
GO

RESTORE DATABASE SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Diff.bak'
WITH NORECOVERY;
GO

RESTORE LOG SmartBankDB_Recovery
FROM DISK = 'C:\SQLAssignment\SQLBackups\SmartBankDB_Log.trn'
WITH RECOVERY;
GO

-- 8. Check Restore Database (Should be the value when transaction log backup activate)
USE SmartBankDB_Recovery;
GO

SELECT AccountID, Balance
FROM Account
WHERE AccountID = 'A000000001';
GO

-- 9. Recover to SmartBank_DB
-- Disconnet all uses
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