# SmartBankDB — Role Permission Summary

This document summarizes every `GRANT`, `DENY`, and role-scoped permission assigned in the SmartBankDB project, organized by role. It is intended as a companion reference for the security report, covering Confidentiality, Integrity, and Data Protection Enhancement sections.

---

## db_admin (DBA)

| Permission | Object | Purpose |
|---|---|---|
| `GRANT CREATE TABLE, ALTER ANY SCHEMA` | Database | Only DBA may create/manage schema (tables), never data |
| `DENY INSERT, UPDATE, DELETE` | Staff, Customer, Account, TransactionRecord | DBA is explicitly blocked from touching data directly, even though they manage schema |
| `GRANT SELECT` | `vw_MyStaffRecord` | DBA may view only their own Staff record |
| `GRANT SELECT` | `vw_StaffPublic` | DBA (like everyone) may view public staff name/phone directory |
| `GRANT EXECUTE` | `sp_UpdateOwnStaffRecord` | DBA may update their own Staff record (name/phone/branch), excluding Salary |

**Explicitly denied:** all base-table DML; creating/managing any business data (Staff, Customer, Account, Transaction rows).

---

## bank_manager

| Permission | Object | Purpose |
|---|---|---|
| `DENY CREATE TABLE, ALTER ANY SCHEMA` | Database | Cannot create/alter schema — that's DBA-only |
| `DENY INSERT, UPDATE, DELETE` | Staff, Customer, Account, TransactionRecord | All writes must go through stored procedures, never direct DML |
| `GRANT SELECT` | `vw_MyStaffRecord` | View own Staff record |
| `GRANT SELECT` | `vw_AllBankOfficers` | View all Bank Officer staff records |
| `GRANT SELECT` | `vw_AllCustomer` | View all customer records |
| `GRANT SELECT` | `vw_AllTransactions` | View all transaction records |
| `GRANT SELECT` | `vw_StaffPublic` | View public staff directory |
| `GRANT EXECUTE` | `sp_UpdateOwnStaffRecord` | Update own record (excludes Salary) |
| `GRANT EXECUTE` | `sp_InsertBankOfficer` | Create new Bank Officer staff records (Position hardcoded, cannot create other Bank Managers/DBAs) |
| `GRANT EXECUTE` | `sp_UpdateBankOfficer` | Update Bank Officer records only (target's Position checked server-side) |
| `GRANT EXECUTE` | `sp_DeleteBankOfficer` | Delete Bank Officer records only (same server-side check) |
| `GRANT UNMASK ON Staff(Salary)` | Column-level | Only Bank Manager sees real Salary values; all other roles see masked/random values |

**Explicitly denied:** managing peers (other Bank Managers) or DBA staff records; any direct table DML; schema changes.

---

## bank_officer

| Permission | Object | Purpose |
|---|---|---|
| `DENY CREATE TABLE, ALTER ANY SCHEMA` | Database | Cannot create/alter schema |
| `DENY INSERT, UPDATE, DELETE` | Staff, Customer, Account, TransactionRecord | All writes via stored procedures only |
| `GRANT SELECT` | `vw_MyStaffRecord` | View own Staff record |
| `GRANT SELECT` | `vw_AllCustomer` | View all customer records |
| `GRANT SELECT` | `vw_AllTransactions` | View all transaction records |
| `GRANT SELECT` | `vw_StaffPublic` | View public staff directory |
| `GRANT EXECUTE` | `sp_UpdateOwnStaffRecord` | Update own record (excludes Salary) |
| `GRANT EXECUTE` | `sp_InsertCustomer` | Create new Customer records (CustomerID auto-generated, IC Number encrypted) |
| `GRANT EXECUTE` | `sp_UpdateCustomer` | Update Customer records (IC Number re-encrypted if changed) |
| `GRANT EXECUTE` | `sp_DeleteCustomer` | Delete Customer records |
| `GRANT EXECUTE` | `sp_CreateAccount` | Create new Account records, including initial PIN (hashed + salted) |
| `GRANT CONTROL ON CERTIFICATE::CustomerICCert` | Certificate | Required to open the symmetric key used to encrypt/decrypt IC Number inside sp_InsertCustomer / sp_UpdateCustomer |
| `GRANT CONTROL ON SYMMETRIC KEY::CustomerICKey` | Symmetric Key | Required (alongside the certificate grant) to actually open and use the key for ENCRYPTBYKEY calls |

**Explicitly denied:** managing Staff records; any direct table DML; schema changes; no `UNMASK` grant (sees masked Customer.Phone and masked Staff.Salary like any other non-Bank-Manager role).

---

## customer

| Permission | Object | Purpose |
|---|---|---|
| `DENY CREATE TABLE, ALTER ANY SCHEMA` | Database | Cannot create/alter schema |
| `DENY INSERT, UPDATE, DELETE` | Staff, Customer, Account, TransactionRecord | All writes via stored procedures only |
| `GRANT SELECT` | `vw_MyCustomerAccounts` | View only their own Customer record (filtered by `SUSER_SNAME()`) |
| `GRANT SELECT` | `vw_MyTransactionRecords` | View only their own transactions (joined through Account, filtered by ownership) |
| `GRANT SELECT` | `vw_StaffPublic` | View public staff directory (e.g. to contact their Bank Officer) |
| `GRANT EXECUTE` | `sp_Deposit` | Deposit funds into their own account (no PIN required by design) |
| `GRANT EXECUTE` | `sp_Withdraw` | Withdraw funds from their own account (PIN verification required) |
| `GRANT EXECUTE` | `sp_Transfer` | Transfer funds to another account (PIN verification required, destination validated) |

**Explicitly denied:** viewing any Staff record beyond the public directory; viewing any other customer's data or transactions; no `UNMASK` grant on any column; any procedure that manages Staff/Customer/Account records.

---

## Cross-Role Notes

- **Least privilege via column-level UNMASK:** Only `bank_manager` has `UNMASK` on `Staff.Salary`. This is deliberately scoped at the *column* level (`GRANT UNMASK ON Staff(Salary)`), not the database level, so Bank Manager does not also gain visibility into masked `Customer.Phone` — a broader `GRANT UNMASK TO bank_manager` (no column specified) would have over-granted.
- **`Staff.Phone` is intentionally never masked**, since `vw_StaffPublic` requires it to be visible to *all* roles — masking it would conflict with that requirement. Only `Customer.Phone` and `Staff.Salary` are masked.
- **Encryption permissions (certificate + symmetric key) do not follow normal ownership chaining.** Even though `bank_officer` has `EXECUTE` on `sp_InsertCustomer`/`sp_UpdateCustomer` (both owned by `dbo`, same as the certificate/key), SQL Server still requires explicit `CONTROL` grants on both the certificate and the symmetric key independently — this is a documented SQL Server behavior specific to encryption objects, not a general permission pattern.
- **No role has any `CREATE LOGIN` / `CREATE USER` permission.** Login/user provisioning is treated as a separate administrative action performed outside all four business roles, to avoid any indirect privilege-escalation path (see design rationale in the Integrity section of the report).
