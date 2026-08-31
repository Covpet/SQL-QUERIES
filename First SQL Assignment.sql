Select * From dbo.Admissions;
Select * From Admissions where DoctorID=6;

Select * From [dbo].[claims];

-- Question 1

Select * FROM Patients
JOIN Location ON Patients.LocationID = Location.LocationID
Where Location.city = 'New York';

-- Question 2
SELECT * From Doctors
Where Specialty  = 'Cardiology';

-- Question 3
SELECT * From Claims
Where ClaimStatus = 'Approved';

--	Question 4
SELECT * From Admissions
Where Reason = 'Flu';

-- Question 5
SELECT * From Policy
Where CoverageAmount > '100000';

-- Question 6
SELECT * From Patients
Where Gender = 'Female';

-- Question 7
SELECT * From Claims
Where ApprovedAmount = '0';

-- Question 8
SELECT * From Providers
Where ProviderType = 'Hospital';

-- Question 9
SELECT * From Admissions
WHERE AdmissionDate > '2024-03-01';

-- Question 10
SELECT * From Patients
Where DOB > '1990-01-01';