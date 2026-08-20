
---------------------------------------------------------------
-- 1. SET DATABASE TO FULL RECOVERY MODEL
---------------------------------------------------------------

USE master;
GO

ALTER DATABASE SmartBankDB
SET RECOVERY FULL;
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
     NAME = ''SmartBankDB-Full'',
     DESCRIPTION = ''Weekly full backup of SmartBankDB'';
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
     NAME = ''SmartBankDB-Differential'',
     DESCRIPTION = ''Daily differential backup of SmartBankDB'';
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
WITH NOINIT,
     NAME = ''SmartBankDB-Transaction Log'',
     DESCRIPTION = ''Transaction log backup of SmartBankDB'';
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

--- Encryp Backup