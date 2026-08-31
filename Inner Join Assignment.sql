
--- Display Patient names and their claim amounts
SELECT Patients.Firstname, Patients.LastName, Claims.ClaimAmount, Claims.ApprovedAmount
FROM Patients
INNER JOIN Claims ON Patients.PatientID = Claims.PatientID

-- Display Patients names and admission reasons
SELECT Patients.Firstname, Patients.LastName, Admissions.Reason
FROM Patients
INNER JOIN Admissions on Patients.PatientID = Admissions.PatientID

-- Display patient names and proider names 
SELECT Doctors.DoctorName, Providers.ProviderName
FROM Doctors
INNER JOIN Providers ON Doctors.ProviderID = Providers.ProviderID;

-- Display Claim details along with Policy Type
SELECT Claims.ClaimID, Claims.ClaimAmount, Claims.ClaimStatus, Policy.PolicyType
FROM Claims
INNER JOIN Policy ON Claims.PolicyID = Policy.PolicyID;

-- Display patient names with policy types
SELECT Patients.FirstName, Patients.LastName, Policy.PolicyType
FROM Patients
INNER JOIN Claims ON Patients.PatientID = Claims.PatientID
INNER JOIN Policy ON Claims.PolicyID = Policy.PolicyID;

-- Display Admission details with doctor names
SELECT Admissions.AdmissionID, Admissions.Reason, Admissions.RoomNo,
Doctors.DoctorName
FROM Admissions
INNER JOIN Doctors ON Admissions.DoctorID = Doctors.DoctorID;

-- Display Proider aned thier locations
SELECT Providers.ProviderName, Providers.ProviderType, Location.City,
Location.State
FROM Providers
INNER JOIN Location ON Providers.LocationID = Location.LocationID;

-- Display Patients names and proider names related to claims
SELECT Patients.FirstName, Patients.LastName, Providers.ProviderName
FROM Patients
INNER JOIN Claims ON Patients.PatientID = Claims.PatientID
INNER JOIN Providers ON Claims.ProviderID = Providers.ProviderID;

--- Display doctor names and admission room numbers.
SELECT Doctors.DoctorName, Admissions.RoomNo, Admissions.Reason
FROM Doctors
INNER JOIN Admissions ON Admissions.DoctorID = Doctors.DoctorID;

-- Display patients names, doctor names and admission reasons.
SELECT Patients.FirstName, Patients.LastName, Doctors.DoctorName,
Admissions.Reason
FROM Patients
INNER JOIN Admissions ON Patients.PatientID = Admissions.PatientID
INNER JOIN Doctors ON Admissions.DoctorID = Doctors.DoctorID;

