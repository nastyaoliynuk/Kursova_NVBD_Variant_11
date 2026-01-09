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

