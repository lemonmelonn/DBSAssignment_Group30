Use SmartBankDB;
GO

-----------Audit Table----------------
CREATE TABLE AuditLog(
    AuditID     int identity primary key,
    ActionType  varchar(50),
    TableName   varchar(50),
    PerformedBy varchar(50),
    ActionDate  datetime default GETDATE(),
    Status      varchar(20),   -- Success / Failed
    Details     varchar(500)
);
GO

-- 1. Only DBAs may create and manage tables (not data)
GRANT CREATE, ALTER TABLE TO db_admin;
DENY  CREATE, ALTER TABLE TO bank_manager, bank_officer, customer;
-- Lock down base-table DML for everyone; all writes must go through procs.
DENY INSERT, UPDATE, DELETE ON Staff TO bank_manager, bank_officer, customer, db_admin;
DENY INSERT, UPDATE, DELETE ON Customer TO bank_manager, bank_officer, customer, db_admin;
DENY INSERT, UPDATE, DELETE ON Account TO bank_manager, bank_officer, customer, db_admin;
DENY INSERT, UPDATE, DELETE ON TransactionRecord TO bank_manager, bank_officer, customer, db_admin;
GO

-- 4. Each staff can update their own record except salary.
-- Staff can update own record
CREATE PROCEDURE sp_UpdateOwnStaffRecord
    @StaffName varchar(100) = NULL,
	@Branch	varchar(50)     = NULL,
	@Phone	varchar(20)     = NULL
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		UPDATE Staff
		SET StaffName = ISNULL(@StaffName, StaffName)
            Phone = ISNULL(@Phone, Phone),
			Branch = ISNULL(@Branch, Branch)
		WHERE StaffID = SUSER_SNAME();

		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('UPDATE', 'STAFF', SUSER_SNAME(), 'Success', 'Self staff update');
	END TRY
	BEGIN CATCH
		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('UPDATE', 'STAFF', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END
GO
GRANT EXECUTE ON sp_UpdateOwnStaffRecord TO db_admin, bank_manager, bank_officer;

-- 2. Only Bank Managers may manage staff details
-- Insert Bank Officer details
CREATE PROCEDURE sp_InsertBankOfficer
	@StaffName varchar(100)	= NULL,
	@Branch    varchar(50)	= NULL,
    @Phone     varchar(20)	= NULL,
    @Salary    decimal(10,2)= NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NewID varchar(6);

	BEGIN TRY
		SELECT @NewID = 'BO' + RIGHT('0000' +
            CAST(ISNULL(MAX(CAST(SUBSTRING(StaffID,3,LEN(StaffID)) AS INT)), 0) + 1 AS varchar(6)), 4)
        FROM Staff
        WHERE Position = 'Bank Officer';

		INSERT INTO STAFF(StaffID, StaffName, Position, Branch, Phone, Salary)
		VALUES (@NewID, @StaffName, 'Bank Officer', @Branch, @Phone, @Salary);

		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('INSERT', 'STAFF', SUSER_SNAME(), 'Sucecess', 'Created StaffID=' + @NewID);
	END TRY
	BEGIN CATCH
		INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Staff', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
		THROW
	END CATCH
END
GO

-- Update Bank Officer details
CREATE PROCEDURE sp_UpdateBankOfficer
	@StaffID    varchar(6),
	@StaffName  varchar(100)    = NULL,
	@Branch     varchar(50)     = NULL,
    @Phone      varchar(20)     = NULL,
    @Salary     decimal(10,2)   = NULL
AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM Staff WHERE StaffID = @StaffID)
			THROW 50010, 'Staff record not found', 1;

		UPDATE Staff
		SET StaffName	= ISNULL(@StaffName, StaffName),
            Branch		= ISNULL(@Branch, Branch),
            Phone		= ISNULL(@Phone, Phone),
            Salary		= ISNULL(@Salary, Salary)
		WHERE StaffID = @StaffID;

	    INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('UPDATE', 'Staff', SUSER_SNAME(), 'Success', 'Updated StaffID=' + @StaffID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('UPDATE', 'Staff', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

-- Delete Bank Officer records
CREATE PROCEDURE sp_DeleteBankOfficer
	@StaffID varchar(6)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TargetPosition varchar(20);

	BEGIN TRY
		SELECT @TargetPosition = Position FROM Staff WHERE StaffID = @StaffID;
		IF @TargetPosition IS NULL
            THROW 50010, 'Staff record not found', 1;
        IF @TargetPosition <> 'Bank Officer'
            THROW 50011, 'Access denied: can only manage Bank Officer records', 1;
		DELETE FROM Staff WHERE StaffID = @StaffID;

        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('DELETE', 'Staff', SUSER_SNAME(), 'Success', 'Deleted StaffID=' + @StaffID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('DELETE', 'Staff', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

GRANT EXECUTE ON sp_InsertBankOfficer TO bank_manager;
GRANT EXECUTE ON sp_UpdateBankOfficer TO bank_manager;
GRANT EXECUTE ON sp_DeleteBankOfficer TO bank_manager

-- 3. Only Bank Officers may manage customer accounts.
-- Insert New Customer
CREATE PROCEDURE sp_InsertCustomer
	@CustomerName	varchar(100),
	@ICNumber		varchar(20),
	@Phone			varchar(20),
	@Address		varchar(200)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NewID varchar(6);

	BEGIN TRY
		SELECT @NewID = 'C' + RIGHT('0000' +
            CAST(ISNULL(MAX(CAST(SUBSTRING(CustomerID,2,LEN(CustomerID)) AS INT)), 0) + 1 AS varchar(10)), 5)
        FROM Customer;

		INSERT INTO Customer(CustomerID, CustomerName, ICNumber, Phone, Address)
		VALUES(@NewID, @CustomerName, @ICNumber, @Phone, @Address);

		INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Customer', SUSER_SNAME(), 'Success', 'Created CustomerID=' + @NewID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Customer', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE sp_CreateAccount
    @CustomerID     varchar(6),
    @AccountType    varchar(20),
    @Pin            char(6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewID  varchar(10);
    DECLARE @Salt UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Customer WHERE CustomerID = @CustomerID)
            THROW 50050, 'Customer does not exist', 1;
        IF @AccountType NOT IN ('Savings', 'Current', 'Fixed Deposit')
            THROW 50051, 'Invalid account type', 1;
        IF @Pin NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'
            THROW 50052, 'PIN must be exactly 6 digits', 1;

        SELECT @NewID = 'A' + RIGHT('000000000' +
            CAST(ISNULL(MAX(CAST(SUBSTRING(AccountID,2,LEN(AccountID)) AS INT)), 0) + 1 AS varchar(10)), 9)
        FROM Account;
        
        INSERT INTO Account(AccountID, CustomerID, AccountType, Balance, PinHash)


-- Update Customer details'
CREATE PROCEDURE sp_UpdateCustomer
	@CustomerID		varchar(6),
	@CustomerName	varchar(100)= NULL,
	@ICNumber		varchar(20)	= NULL,
	@Phone			varchar(20)	= NULL,
	@Address		varchar(200)= NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Customer WHERE CustomerID = @CustomerID)
            THROW 50020, 'Customer record not found', 1;

        UPDATE Customer
        SET CustomerName = ISNULL(@CustomerName, CustomerName),
            ICNumber     = ISNULL(@ICNumber, ICNumber),
            Phone        = ISNULL(@Phone, Phone),
            Address      = ISNULL(@Address, Address)
        WHERE CustomerID = @CustomerID;

        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('UPDATE', 'Customer', SUSER_SNAME(), 'Success', 'Updated CustomerID=' + @CustomerID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('UPDATE', 'Customer', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

-- Delete Customer record
CREATE PROCEDURE sp_DeleteCustomer
	@CustomerID varchar(6)
AS
BEGIN
    SET NOCOUNT ON;
	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM Customer WHERE CustomerID = @CustomerID)
            THROW 50020, 'Customer record not found', 1;

		DELETE FROM Customemr WHERE CustomerID = @CustomerID;

		INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('DELETE', 'Customer', SUSER_SNAME(), 'Success', 'Deleted CustomerID=' + @CustomerID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('DELETE', 'Customer', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

GRANT EXECUTE ON sp_InsertCustomer TO bank_officer;
GRANT EXECUTE ON sp_UpdateCustomer TO bank_officer;
GRANT EXECUTE ON sp_DeleteCustomer TO bank_officer;
GO

-- 5. Only Customers may perform transactions. Valid transactions are deposit, withdrawal, and transfer.
-- deposit
CREATE PROCEDURE sp_Deposit
    @AccountID  varchar(10),
    @Amount     decimal(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OwnerID varchar(6);

    BEGIN TRY
        SELECT @OwnerID = CustomerID FROM Account WHERE AccountID = @AccountID;

        IF @OwnerID IS NULL
            THROW 50030, 'Account does not exist',1;
        IF @OwnerID <> SUSER_SNAME()
            THROW 50031,'Access denied: not your account',1;
        IF @Amount <= 0
            THROW 50032,'Invalid amount',1;

        BEGIN TRANSACTION;
        UPDATE Account SET Balance = Balance + @Amount WHERE AccountID = @AccountID;

        INSERT INTO TransactionRecord (AccountID, TransDate, Amount, TransactionType)
        VALUES (@AccountID, GETDATE(), @Amount, 'Deposit');
        COMMIT TRANSACTION;

        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES('Deposit', 'TransactionRecord', SUSER_SNAME(), 'Success', 'Deposit Amount=' + CAST(@Amount AS varchar(20)));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES('Deposit', 'TransactionRecord', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO 

CREATE PROCEDURE sp_Withdraw
    @AccountID varchar(10)
    @Amount decimal (12,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OwnerID varchar(6);

    BEGIN TRY
        Select @Owner = CustomerID FROM Account WHERE AccountID = @AccountID;

        IF @Owner IS NULL
            THROW 50030, 'Account does not exist', 1
        IF @Owner <> SUSER_SNAME()
            THROW 50031, 'Access denied: not your account',1;
        IF @Amount <= 0
            THROW 50032, 'Invalid amount', 1;
        IF (SELECT Balance FROM Account WHERE AccountID = @AccountID) < @Amount
            THROW 50033, 'Insuffiecient amount', 1;
        
        BEGIN TRANSACTION;
        UPDATE Account 
            SET Balance = Balance - @Amount WHERE AccountID = @AccountID;

        INSERT INTO TransactionRecord(AccountID, TransDate, Amount, TransactionType)
        VALUES (@AccountID, GETDATE(), @Amount, 'Withdrawal');
        COMMIT TRANSACTION;
        
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('Withdrawal', 'TransactionRecord', SUSER_SNAME(), 'Success', 'Withdraw Amount=' + CAST(@Amount AS varchar(20)));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('Withdrawal', 'TransactionRecord', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE sp_Transfer
    @AccountID      varchar(10),
    @ToAccountID    varchar(10),
    @Amount         decimal(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Owner  varchar(6);

    BEGIN TRY
        SELECT @Owner = CustomerID FROM Account WHERE AccountID = @AccountID;

        IF @Owner IS NULL
            THROW 50030, 'Account does not exist', 1;
        IF NOT EXISTS (SELECT AccountID FROM Account WHERE AccountID = @ToAccountID)
            THROW 50030, 'Account does not exist', 1;
        IF @Owner <> SUSER_SNAME()
            THROW 50031, 'Access denied: not your account', 1;
        IF @Amount <= 0
            THROW 50032, 'Invalid amount', 1;
        IF (SELECT Balance FROM Account WHERE AccountID = @AccountID) < @Amount
            THROW 50033, 'Insuffiecient amount', 1;
        IF  @ToAccountID = @AccountID
            THROW 50034, 'Cannot transfer to the same account', 1;
        
        BEGIN TRANSACTION;
        UPDATE Account 
            SET Balance = Balance - @Amount WHERE AccountID = @AccountID;
        UPDATE Account
            SET Balance = Balance + @Amount WHERE AccountID = @ToAccountID;
        INSERT INTO TransactionRecord(AccountID, TransDate, Amount, TransactionType)
        VALUES(@AccountID, GETDATE(), @Amount, 'Transfer');

        COMMIT TRANSACTION;
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('Transfer', 'TransactionRecord', SUSER_SNAME(), 'Success', 'From=' + @AccountID + ' To=' + @ToAccountID + 'Transfer Amount=' + CAST(@Amount AS varchar(20)));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('Transfer', 'TransactionRecord', SUSER_SNAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

GRANT EXECUTE ON sp_Deposit  TO customer;
GRANT EXECUTE ON sp_Withdraw TO customer;
GRANT EXECUTE ON sp_Transfer TO customer;