-- Data Science Practice Queries
-- Using the Patients, Claims, Admissions, Doctors, Providers, Policy and Location tables

-- Question 1
-- Count how many claims there are for each claim status
SELECT ClaimStatus, COUNT(*) AS NumberOfClaims
FROM Claims
GROUP BY ClaimStatus
ORDER BY NumberOfClaims DESC;

-- Question 2
-- Check for missing values in the Claims table
SELECT COUNT(*) AS TotalClaims,
SUM(CASE WHEN ClaimAmount IS NULL THEN 1 ELSE 0 END) AS MissingClaimAmount,
SUM(CASE WHEN ApprovedAmount IS NULL THEN 1 ELSE 0 END) AS MissingApprovedAmount
FROM Claims;

-- Question 3
-- Find duplicate patients (same name and date of birth)
SELECT FirstName, LastName, DOB, COUNT(*) AS Total
FROM Patients
GROUP BY FirstName, LastName, DOB
HAVING COUNT(*) > 1;

-- Question 4
-- Summary statistics for claim amounts
SELECT COUNT(ClaimAmount) AS Total,
MIN(ClaimAmount) AS Minimum,
MAX(ClaimAmount) AS Maximum,
AVG(ClaimAmount) AS Average,
STDEV(ClaimAmount) AS StandardDeviation
FROM Claims;

-- Question 5
-- Median claim amount
SELECT DISTINCT
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS MedianClaimAmount
FROM Claims;

-- Question 6
-- Average claim and total approved amount for each policy type
SELECT Policy.PolicyType, COUNT(*) AS NumberOfClaims,
AVG(Claims.ClaimAmount) AS AverageClaim,
SUM(Claims.ApprovedAmount) AS TotalApproved
FROM Claims
INNER JOIN Policy ON Claims.PolicyID = Policy.PolicyID
GROUP BY Policy.PolicyType;

-- Question 7
-- Most common reason for admission
SELECT TOP 1 Reason, COUNT(*) AS Total
FROM Admissions
GROUP BY Reason
ORDER BY Total DESC;

-- Question 8
-- Claims that are much higher than average (more than 2 standard deviations)
SELECT ClaimID, ClaimAmount
FROM Claims
WHERE ClaimAmount > (SELECT AVG(ClaimAmount) + 2 * STDEV(ClaimAmount) FROM Claims);

-- Question 9
-- Percentage of the claim amount that was approved
SELECT ClaimID, ClaimAmount, ApprovedAmount,
ApprovedAmount * 100.0 / ClaimAmount AS ApprovedPercent
FROM Claims
WHERE ClaimAmount > 0;

-- Question 10
-- Patient age and age group
SELECT FirstName, LastName, DOB,
DATEDIFF(YEAR, DOB, GETDATE()) AS Age,
CASE
    WHEN DATEDIFF(YEAR, DOB, GETDATE()) < 18 THEN 'Child'
    WHEN DATEDIFF(YEAR, DOB, GETDATE()) < 40 THEN 'Young Adult'
    WHEN DATEDIFF(YEAR, DOB, GETDATE()) < 65 THEN 'Adult'
    ELSE 'Senior'
END AS AgeGroup
FROM Patients;

-- Question 11
-- Number of patients in each age group by gender
SELECT Gender,
SUM(CASE WHEN DATEDIFF(YEAR, DOB, GETDATE()) < 40 THEN 1 ELSE 0 END) AS Under40,
SUM(CASE WHEN DATEDIFF(YEAR, DOB, GETDATE()) >= 40 THEN 1 ELSE 0 END) AS Over40
FROM Patients
GROUP BY Gender;

-- Question 12
-- Total amount claimed by each patient
SELECT Patients.FirstName, Patients.LastName, COUNT(Claims.ClaimID) AS NumberOfClaims,
SUM(Claims.ClaimAmount) AS TotalClaimed
FROM Patients
INNER JOIN Claims ON Patients.PatientID = Claims.PatientID
GROUP BY Patients.FirstName, Patients.LastName
ORDER BY TotalClaimed DESC;

-- Question 13
-- Rank providers by total approved amount
SELECT Providers.ProviderName, SUM(Claims.ApprovedAmount) AS TotalApproved,
RANK() OVER (ORDER BY SUM(Claims.ApprovedAmount) DESC) AS ProviderRank
FROM Claims
INNER JOIN Providers ON Claims.ProviderID = Providers.ProviderID
GROUP BY Providers.ProviderName;

-- Question 14
-- Number of admissions handled by each doctor specialty
SELECT Doctors.Specialty, COUNT(Admissions.AdmissionID) AS NumberOfAdmissions
FROM Doctors
INNER JOIN Admissions ON Doctors.DoctorID = Admissions.DoctorID
GROUP BY Doctors.Specialty
ORDER BY NumberOfAdmissions DESC;

-- Question 15
-- Number of admissions per month
SELECT YEAR(AdmissionDate) AS AdmissionYear, MONTH(AdmissionDate) AS AdmissionMonth,
COUNT(*) AS NumberOfAdmissions
FROM Admissions
GROUP BY YEAR(AdmissionDate), MONTH(AdmissionDate)
ORDER BY AdmissionYear, AdmissionMonth;

-- Question 16
-- Running total of admissions over time
SELECT AdmissionID, AdmissionDate,
COUNT(*) OVER (ORDER BY AdmissionDate, AdmissionID) AS RunningTotal
FROM Admissions;

-- Question 17
-- Total claims by city
SELECT Location.City, COUNT(Claims.ClaimID) AS NumberOfClaims,
SUM(Claims.ClaimAmount) AS TotalClaimed
FROM Claims
INNER JOIN Patients ON Claims.PatientID = Patients.PatientID
INNER JOIN Location ON Patients.LocationID = Location.LocationID
GROUP BY Location.City
ORDER BY TotalClaimed DESC;

-- Question 18
-- Split patients into high, medium and low spenders
SELECT PatientID, SUM(ClaimAmount) AS TotalClaimed,
CASE
    WHEN SUM(ClaimAmount) >= 10000 THEN 'High'
    WHEN SUM(ClaimAmount) >= 5000 THEN 'Medium'
    ELSE 'Low'
END AS SpendingGroup
FROM Claims
GROUP BY PatientID;

-- Question 19
-- Random sample of 10 claims
SELECT TOP 10 *
FROM Claims
ORDER BY NEWID();
