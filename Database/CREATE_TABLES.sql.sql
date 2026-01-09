CREATE TABLE Department (
    DepartmentID INT IDENTITY PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    ManagerID INT NULL
);
GO
CREATE TABLE Position (
    PositionID INT IDENTITY PRIMARY KEY,
    PositionName NVARCHAR(100) NOT NULL UNIQUE,
    HourlyRate DECIMAL(10,2) NOT NULL
        CHECK (HourlyRate > 0)
);

GO

CREATE TABLE Employee (
    EmployeeID INT IDENTITY PRIMARY KEY,
    LastName NVARCHAR(50) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    MiddleName NVARCHAR(50),
    PassportNumber NVARCHAR(20) NOT NULL UNIQUE,
    BirthDate DATE NOT NULL,
    Address NVARCHAR(255),
    HireDate DATE NOT NULL,
    DismissDate DATE NULL,

    DepartmentID INT NOT NULL,
    PositionID INT NOT NULL,

    CONSTRAINT FK_Employee_Department
        FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID),

    CONSTRAINT FK_Employee_Position
        FOREIGN KEY (PositionID) REFERENCES Position(PositionID),

    CONSTRAINT CHK_DismissDate
        CHECK (DismissDate IS NULL OR DismissDate >= HireDate)
);

GO

CREATE TABLE TimeSheet (
    TimeSheetID INT IDENTITY PRIMARY KEY,
    EmployeeID INT NOT NULL,
    WorkDate DATE NOT NULL,
    HoursWorked DECIMAL(5,2) NOT NULL CHECK (HoursWorked >= 0),
    DayType NVARCHAR(20) NOT NULL
        CHECK (DayType IN ('WORKDAY', 'OVERTIME', 'WEEKEND', 'HOLIDAY')),

    CONSTRAINT UQ_TimeSheet UNIQUE (EmployeeID, WorkDate),

    CONSTRAINT FK_TimeSheet_Employee
        FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

GO

CREATE TABLE Vacation (
    VacationID INT IDENTITY PRIMARY KEY,
    EmployeeID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    DaysCount INT NOT NULL CHECK (DaysCount > 0),

    CONSTRAINT FK_Vacation_Employee
        FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID),

    CONSTRAINT CHK_VacationDates
        CHECK (EndDate >= StartDate)
);

GO

CREATE TABLE VacationBalance (
    VacationBalanceID INT IDENTITY PRIMARY KEY,
    EmployeeID INT NOT NULL,
    [Year] INT NOT NULL,
    TotalDays INT NOT NULL CHECK (TotalDays >= 0),
    UsedDays INT NOT NULL CHECK (UsedDays >= 0),
    RemainingDays AS (TotalDays - UsedDays) PERSISTED,

    CONSTRAINT UQ_VacationBalance UNIQUE (EmployeeID, [Year]),

    CONSTRAINT FK_VacationBalance_Employee
        FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

GO

CREATE TABLE Payroll (
    PayrollID INT IDENTITY PRIMARY KEY,
    EmployeeID INT NOT NULL,
    [Month] INT NOT NULL CHECK ([Month] BETWEEN 1 AND 12),
    [Year] INT NOT NULL,

    BaseSalary DECIMAL(12,2) NOT NULL CHECK (BaseSalary >= 0),
    ExtraSalary DECIMAL(12,2) NOT NULL CHECK (ExtraSalary >= 0),
    VacationPay DECIMAL(12,2) NOT NULL CHECK (VacationPay >= 0),

    TotalAccrued AS (BaseSalary + ExtraSalary + VacationPay) PERSISTED,
    Tax AS ((BaseSalary + ExtraSalary + VacationPay) * 0.20) PERSISTED,
    NetSalary AS ((BaseSalary + ExtraSalary + VacationPay) - ((BaseSalary + ExtraSalary + VacationPay) * 0.20)) PERSISTED,


    CONSTRAINT UQ_Payroll UNIQUE (EmployeeID, [Month], [Year]),

    CONSTRAINT FK_Payroll_Employee
        FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

GO

CREATE TABLE Payment (
    PaymentID INT IDENTITY PRIMARY KEY,
    PayrollID INT NOT NULL,
    PaymentDate DATE NOT NULL,
    PaidAmount DECIMAL(12,2) NOT NULL CHECK (PaidAmount >= 0),
    Penalty DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT FK_Payment_Payroll
        FOREIGN KEY (PayrollID) REFERENCES Payroll(PayrollID)
);