/* ============================================================
   SMARTBANK DATABASE - COMPLETE RESET SCRIPT
   Purpose:
   Remove all SmartBankDB demo objects so the setup
   can be executed again from a clean state.

   WARNING:
   This will permanently delete SmartBankDB and its data.
   ============================================================ */


---------------------------------------------------------------
-- 1. DELETE SQL SERVER AGENT JOBS
---------------------------------------------------------------

USE msdb;
GO

DECLARE @JobName sysname;

DECLARE JobCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM dbo.sysjobs
WHERE name IN
(
    N'SmartBankDB - Full Backup',
    N'SmartBankDB - Differential Backup',
    N'SmartBankDB - Transaction Log Backup'
);

OPEN JobCursor;

FETCH NEXT FROM JobCursor INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Deleting job: ' + @JobName;

    EXEC dbo.sp_delete_job
        @job_name = @JobName,
        @delete_unused_schedule = 1;

    FETCH NEXT FROM JobCursor INTO @JobName;
END;

CLOSE JobCursor;
DEALLOCATE JobCursor;
GO


---------------------------------------------------------------
-- 2. DELETE SMARTBANK BACKUP SCHEDULES
--    (In case any schedules remain unattached)
---------------------------------------------------------------

USE msdb;
GO

DECLARE @ScheduleID INT;
DECLARE @ScheduleName sysname;

DECLARE ScheduleCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT schedule_id, name
FROM dbo.sysschedules
WHERE name LIKE N'SmartBankDB -%';

OPEN ScheduleCursor;

FETCH NEXT FROM ScheduleCursor
INTO @ScheduleID, @ScheduleName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Deleting schedule: ' + @ScheduleName;

    EXEC dbo.sp_delete_schedule
        @schedule_id = @ScheduleID;

    FETCH NEXT FROM ScheduleCursor
    INTO @ScheduleID, @ScheduleName;
END;

CLOSE ScheduleCursor;
DEALLOCATE ScheduleCursor;
GO

---------------------------------------------------------------
-- 3. DROP TEST DATABASES
---------------------------------------------------------------

USE master;
GO

-- Drop SmartBankDB
IF DB_ID(N'SmartBankDB') IS NOT NULL
BEGIN
    PRINT 'Dropping SmartBankDB...';

    ALTER DATABASE SmartBankDB
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;

    DROP DATABASE SmartBankDB;

    PRINT 'SmartBankDB successfully deleted.';
END
ELSE
BEGIN
    PRINT 'SmartBankDB does not exist.';
END
GO


-- Drop recovery test database
IF DB_ID(N'SmartBankDB_Recovery_test') IS NOT NULL
BEGIN
    PRINT 'Dropping SmartBankDB_Recovery_test...';

    ALTER DATABASE SmartBankDB_Recovery_test
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;

    DROP DATABASE SmartBankDB_Recovery_test;

    PRINT 'SmartBankDB_Recovery_test successfully deleted.';
END
ELSE
BEGIN
    PRINT 'SmartBankDB_Recovery_test does not exist.';
END
GO

---------------------------------------------------------------
-- 4. DROP SERVER AUDIT SPECIFICATION
---------------------------------------------------------------

USE master;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.server_audit_specifications
    WHERE name = N'SmartBankServerAudit'
)
BEGIN
    PRINT 'Dropping SmartBankServerAudit...';

    ALTER SERVER AUDIT SPECIFICATION SmartBankServerAudit
        WITH (STATE = OFF);

    DROP SERVER AUDIT SPECIFICATION SmartBankServerAudit;
END
ELSE
BEGIN
    PRINT 'SmartBankServerAudit does not exist.';
END
GO


---------------------------------------------------------------
-- 5. DROP SERVER AUDIT
---------------------------------------------------------------

USE master;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.server_audits
    WHERE name = N'SmartBankAudit'
)
BEGIN
    PRINT 'Dropping SmartBankAudit...';

    ALTER SERVER AUDIT SmartBankAudit
        WITH (STATE = OFF);

    DROP SERVER AUDIT SmartBankAudit;
END
ELSE
BEGIN
    PRINT 'SmartBankAudit does not exist.';
END
GO


---------------------------------------------------------------
-- 6. DROP SQL SERVER LOGINS
---------------------------------------------------------------
---------------------------------------------------------------
-- 6. DROP SQL SERVER LOGINS
---------------------------------------------------------------

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'BM0001')
    DROP LOGIN [BM0001];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'BM0002')
    DROP LOGIN [BM0002];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'BO0001')
    DROP LOGIN [BO0001];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'BO0002')
    DROP LOGIN [BO0002];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'C00001')
    DROP LOGIN [C00001];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'C00002')
    DROP LOGIN [C00002];
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'DB0001')
    DROP LOGIN [DB0001];
GO


---------------------------------------------------------------
-- 7. FINAL VERIFICATION
---------------------------------------------------------------

USE master;
GO

SELECT
    CASE
        WHEN DB_ID(N'SmartBankDB') IS NULL
        THEN 'PASS - SmartBankDB does not exist'
        ELSE 'FAIL - SmartBankDB still exists'
    END AS DatabaseCheck;

SELECT
    name AS RemainingSmartBankLogin
FROM sys.server_principals
WHERE name IN
(
    N'BM0001',
    N'BM0002',
    N'BO0001',
    N'BO0002',
    N'C00001',
    N'C00002'
);

USE msdb;
GO

SELECT
    name AS RemainingSmartBankJob
FROM dbo.sysjobs
WHERE name LIKE N'SmartBankDB -%';

SELECT
    name AS RemainingSmartBankSchedule
FROM dbo.sysschedules
WHERE name LIKE N'SmartBankDB -%';

USE master;
GO

SELECT
    name AS RemainingSmartBankAudit
FROM sys.server_audits
WHERE name = N'SmartBankAudit';

SELECT
    name AS RemainingSmartBankAuditSpecification
FROM sys.server_audit_specifications
WHERE name = N'SmartBankServerAudit';
GO