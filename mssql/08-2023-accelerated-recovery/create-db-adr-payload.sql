USE master
GO

CREATE DATABASE RecoveryTestingADR;
GO 
-- SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB, LOGSIZE = 8192KB
-- RECOVERY MODEL = FULL

ALTER DATABASE RecoveryTestingADR
SET ACCELERATED_DATABASE_RECOVERY = ON; -- ADR
GO

----------------------------------------------
-- X
----------------------------------------------
USE RecoveryTestingADR;
GO

DROP TABLE IF EXISTS dbo.Table1, dbo.Table1, dbo.Table1;

SELECT s2.* INTO dbo.Table1 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table2 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;
SELECT s2.* INTO dbo.Table3 
FROM sys.all_parameters AS s1 
CROSS JOIN sys.all_columns AS s2;

----------------------------------------------
----------------------------------------------

USE RecoveryTestingADR;
GO

SELECT name, type_desc, state_desc, 8*size sizeKb 
FROM sys.database_files;


----------------------------------------------
----------------------------------------------
USE master
GO

ALTER DATABASE RecoveryTestingADR 
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

DROP DATABASE RecoveryTestingADR;