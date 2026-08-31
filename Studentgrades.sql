-- Question 1

SELECT * FROM Names
ORDER BY studentnames ASC
LIMIT 100;

-- Question 1b;
SELECT COUNT(*) FROM Names
WHERE studentnames like 'Amanda%'

SELECT COUNT (*) FROM Names
WHERE studentnames like 'John%';

SELECT COUNT (*) FROM Overallgrade
WHERE finalmark > 90;







--Question 2a
SELECT Attendance.studentids, Attendance.studentattendance, OverallGrade.finalmark
FROM Attendance 
INNER JOIN OverallGrade ON Attendance.studentids = OverallGrade.studentids
LIMIT 100;

-- Question 2b

SELECT COUNT(*) FROM Attendance
where studentattendance BETWEEN 60 AND 80;

-- Question 2C
SELECT AVG(finalmark) FROM Attendance
INNER JOIN OverallGrade ON  Attendance.studentids = OverallGrade.studentids
where studentattendance BETWEEN 60 AND 80;

-- Question 2D
SELECT 
    (SELECT AVG(finalmark) 
     FROM Attendance
     INNER JOIN OverallGrade ON Attendance.studentids = OverallGrade.studentids
     WHERE studentattendance BETWEEN 60 AND 80)
     -
    (SELECT AVG(finalmark)
     FROM Attendance
     INNER JOIN OverallGrade ON Attendance.studentids = OverallGrade.studentids
     WHERE studentattendance BETWEEN 20 AND 40) AS difference;
	 
-- Question 3

SELECT studentids, assignment1
FROM Assignments
WHERE assignment1 > 70;

-- Question 3B

SELECT AVG(assignment1), AVG(assignment2), AVG(assignment3), AVG(assignment4), AVG(assignment5)
FROM Assignments

-- Question 3C
SELECT *
FROM Assignments
JOIN OverallGrade ON Assignments.studentids = OverallGrade.studentids
WHERE OverallGrade.finalmark > 90;

-- Question 3D
SELECT MIN(assignment1)
FROM Assignments
JOIN OverallGrade ON Assignments.studentids = OverallGrade.studentids
WHERE OverallGrade.finalmark > 90;



SELECT assignment1
FROM Assignments
JOIN OverallGrade USING (studentids)
WHERE finalmark >= 90
ORDER BY assignment1
LIMIT 1;





