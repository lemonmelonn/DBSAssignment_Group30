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
