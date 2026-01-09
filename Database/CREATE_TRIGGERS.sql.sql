DROP TRIGGER IF EXISTS TRG_NoPayrollAfterDismiss;
GO

CREATE TRIGGER TRG_NoPayrollAfterDismiss
ON Payroll
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Employee e ON e.EmployeeID = i.EmployeeID
        WHERE e.DismissDate IS NOT NULL
          AND (
              i.[Year] > YEAR(e.DismissDate)
              OR (i.[Year] = YEAR(e.DismissDate)
                  AND i.[Month] > MONTH(e.DismissDate))
          )
    )
    BEGIN
        RAISERROR ('���������� ������������ �������� ���� ����� ��������� ����������.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


GO

DROP TRIGGER IF EXISTS TRG_MinSalary;
GO

CREATE TRIGGER TRG_MinHourlyRate
ON Payroll
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @MinHourlyRate DECIMAL(10,2) = 50;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Employee e ON e.EmployeeID = i.EmployeeID
        JOIN Position p ON p.PositionID = e.PositionID
        WHERE p.HourlyRate < @MinHourlyRate
    )
    BEGIN
        RAISERROR ('��������� ������ �� ���� ���� ������ �� ���������.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;


GO

DROP TRIGGER IF EXISTS TRG_VacationLimit;
GO

CREATE TRIGGER TRG_VacationLimit
ON Vacation
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Employee e ON e.EmployeeID = i.EmployeeID
        JOIN Employee e2 ON e2.DepartmentID = e.DepartmentID
        JOIN Vacation v ON v.EmployeeID = e2.EmployeeID
        WHERE v.StartDate <= i.EndDate
          AND v.EndDate >= i.StartDate
        GROUP BY e.DepartmentID
        HAVING COUNT(DISTINCT e2.EmployeeID) >
               (SELECT COUNT(*) * 0.15
                FROM Employee
                WHERE DepartmentID = e.DepartmentID)
    )
    BEGIN
        RAISERROR ('� �������� �� ���� ���������� ����� 15%% ���������� ����� ���������.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


DROP TRIGGER IF EXISTS TRG_PaymentPenalty;
GO

CREATE TRIGGER TRG_PaymentPenalty
ON Payment
AFTER INSERT
AS
BEGIN
    UPDATE p
    SET Penalty =
        CASE
            WHEN p.PaymentDate >
                 DATEADD(DAY, 10,
                     DATEFROMPARTS(pr.[Year], pr.[Month], 1))
            THEN
                DATEDIFF(
                    DAY,
                    DATEADD(DAY, 10,
                        DATEFROMPARTS(pr.[Year], pr.[Month], 1)),
                    p.PaymentDate
                ) * p.PaidAmount * 0.001
            ELSE 0
        END
    FROM Payment p
    JOIN inserted i ON p.PaymentID = i.PaymentID
    JOIN Payroll pr ON pr.PayrollID = p.PayrollID;
END;
GO

CREATE TRIGGER TRG_UpdateVacationBalance
ON Vacation
AFTER INSERT
AS
BEGIN
    UPDATE vb
    SET UsedDays = UsedDays + i.DaysCount
    FROM VacationBalance vb
    JOIN inserted i ON vb.EmployeeID = i.EmployeeID
       AND vb.[Year] = YEAR(i.StartDate);
END;
GO


CREATE FUNCTION fn_VacationPay
(
    @TotalSalary DECIMAL(12,2),
    @VacationDays INT,
    @HolidayDays INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN (@TotalSalary / (365 - @HolidayDays)) * @VacationDays;
END;

GO

CREATE PROCEDURE sp_CalculatePayroll
    @EmployeeID INT,
    @Month INT,
    @Year INT
AS
BEGIN
    DECLARE @Base DECIMAL(12,2);
    DECLARE @Extra DECIMAL(12,2);

    SELECT
        @Base = SUM(CASE WHEN DayType = 'WORKDAY'
                         THEN HoursWorked * p.HourlyRate
                         ELSE 0 END),
        @Extra = SUM(CASE
                        WHEN DayType = 'OVERTIME'
                            THEN HoursWorked * p.HourlyRate * 2
                        WHEN DayType IN ('WEEKEND','HOLIDAY')
                            THEN HoursWorked * p.HourlyRate * 3
                        ELSE 0 END)
    FROM TimeSheet t
    JOIN Employee e ON e.EmployeeID = t.EmployeeID
    JOIN Position p ON p.PositionID = e.PositionID
    WHERE t.EmployeeID = @EmployeeID
      AND MONTH(t.WorkDate) = @Month
      AND YEAR(t.WorkDate) = @Year;

    INSERT INTO Payroll (EmployeeID, [Month], [Year], BaseSalary, ExtraSalary, VacationPay)
    VALUES (@EmployeeID, @Month, @Year, ISNULL(@Base,0), ISNULL(@Extra,0), 0);
END;

GO

CREATE TRIGGER TRG_NoVacationOverlap
ON Vacation
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Vacation v
        JOIN inserted i ON v.EmployeeID = i.EmployeeID
        WHERE v.VacationID <> i.VacationID
          AND i.StartDate <= v.EndDate
          AND i.EndDate >= v.StartDate
    )
    BEGIN
        RAISERROR ('³������� ������ ���������� �� ������ ������������.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

DROP TRIGGER IF EXISTS TRG_NoOverpayment;
GO

CREATE TRIGGER TRG_NoOverpayment
ON Payment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM Payroll pr
        JOIN (
            SELECT PayrollID, SUM(PaidAmount) AS TotalPaid
            FROM Payment
            GROUP BY PayrollID
        ) p ON p.PayrollID = pr.PayrollID
        JOIN inserted i ON i.PayrollID = pr.PayrollID
        WHERE p.TotalPaid > pr.NetSalary
    )
    BEGIN
        RAISERROR (
            '���� ������ �������� ���������� ���� �� �������.',
            16, 1
        );
        ROLLBACK TRANSACTION;
    END
END;
GO
