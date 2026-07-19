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
GRANT CREATE TABLE TO db_admin;
DENY  CREATE TABLE TO bank_manager, bank_officer, customer;
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
		WHERE StaffID = SUSER_NAME()

		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('UPDATE', 'STAFF', SUSER_NAME(), 'Success', 'Self staff update');
	END TRY
	BEGIN CATCH
		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('UPDATE', 'STAFF', SUSER_NAME(), 'Failed', ERROR_MESSAGE());
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
	DECLARE @NewID varchar(10);

	BEGIN TRY
		SELECT @NewID = 'BO' + RIGHT('0000' +
            CAST(ISNULL(MAX(CAST(SUBSTRING(StaffID,3,LEN(StaffID)) AS INT)), 0) + 1 AS varchar(10)), 4)
        FROM Staff
        WHERE Position = 'Bank Officer';

		INSERT INTO STAFF(StaffID, StaffName, Position, Branch, Phone, Salary)
		VALUES (@NewID, @StaffName, 'Bank Officer', @Branch, @Phone, @Salary);

		INSERT INTO AuditLog (ActionType, TableName, PerformedBy, Status, Details)
		VALUES ('INSERT', 'STAFF', SUSER_NAME(), 'Sucecess', 'Created StaffID=' + @NewID);
	END TRY
	BEGIN CATCH
		INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Staff', SUSER_NAME(), 'Failed', ERROR_MESSAGE());
		THROW
	END CATCH
END
GO

-- Update Bank Officer details
CREATE PROCEDURE sp_UpdateBankOfficer
	@StaffID varchar(10),
	@StaffName varchar(100)	= NULL,
	@Branch    varchar(50)  = NULL,
    @Phone     varchar(20)  = NULL,
    @Salary    decimal(10,2)= NULL
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
        VALUES ('UPDATE', 'Staff', SUSER_NAME(), 'Success', 'Updated StaffID=' + @StaffID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('UPDATE', 'Staff', SUSER_NAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

-- Delete Bank Officer records
CREATE PROCEDURE sp_DeleteBankOfficer
	@StaffID varchar(10)
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
        VALUES ('DELETE', 'Staff', SUSER_NAME(), 'Success', 'Deleted StaffID=' + @StaffID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('DELETE', 'Staff', SUSER_NAME(), 'Failed', ERROR_MESSAGE());
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
	DECLARE @NewID varchar(10);

	BEGIN TRY
		SELECT @NewID = 'C' + RIGHT('0000' +
            CAST(ISNULL(MAX(CAST(SUBSTRING(CustomerID,2,LEN(CustomerID)) AS INT)), 0) + 1 AS varchar(10)), 5)
        FROM Customer;

		INSERT INTO Customer(CustomerID, CustomerName, ICNumber, Phone, Address)
		VALUES(@NewID, @CustomerName, @ICNumber, @Phone, @Address);

		INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Customer', SUSER_NAME(), 'Success', 'Created CustomerID=' + @NewID);
    END TRY
    BEGIN CATCH
        INSERT INTO AuditLog(ActionType, TableName, PerformedBy, Status, Details)
        VALUES ('INSERT', 'Customer', SUSER_NAME(), 'Failed', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

-- Update Customer details'
CREATE PROCEDURE sp_UpdateCustomer
	@CustomerID		varchar(10),
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