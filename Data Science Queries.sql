-- =====================================================================
-- Data Science Queries (SQL Server / T-SQL)
-- Built on the healthcare tables used in the other assignments:
--   Patients, Claims, Admissions, Doctors, Providers, Policy, Location
-- Sections:
--   1. Data profiling          6. Window functions & ranking
--   2. Data quality checks     7. Time series analysis
--   3. Descriptive statistics  8. Segmentation & cohorts
--   4. Outlier detection       9. Correlation
--   5. Feature engineering    10. Train / test split
-- =====================================================================


-- =====================================================================
-- 1. DATA PROFILING
-- =====================================================================

-- Row counts for every table
SELECT 'Patients'   AS TableName, COUNT(*) AS RowCnt FROM Patients
UNION ALL SELECT 'Claims',     COUNT(*) FROM Claims
UNION ALL SELECT 'Admissions', COUNT(*) FROM Admissions
UNION ALL SELECT 'Doctors',    COUNT(*) FROM Doctors
UNION ALL SELECT 'Providers',  COUNT(*) FROM Providers
UNION ALL SELECT 'Policy',     COUNT(*) FROM Policy
UNION ALL SELECT 'Location',   COUNT(*) FROM Location;

-- Missing values per column in Claims (count and percentage)
SELECT
    COUNT(*)                                                        AS TotalRows,
    SUM(CASE WHEN ClaimAmount    IS NULL THEN 1 ELSE 0 END)         AS Null_ClaimAmount,
    SUM(CASE WHEN ApprovedAmount IS NULL THEN 1 ELSE 0 END)         AS Null_ApprovedAmount,
    SUM(CASE WHEN ClaimStatus    IS NULL THEN 1 ELSE 0 END)         AS Null_ClaimStatus,
    100.0 * SUM(CASE WHEN ApprovedAmount IS NULL THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0)                                     AS Pct_Null_ApprovedAmount
FROM Claims;

-- Cardinality (distinct values) of categorical columns
SELECT
    COUNT(DISTINCT Gender)     AS Distinct_Gender,
    COUNT(DISTINCT LocationID) AS Distinct_Location
FROM Patients;

-- Frequency table of a categorical column
SELECT
    ClaimStatus,
    COUNT(*)                                          AS Frequency,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Pct
FROM Claims
GROUP BY ClaimStatus
ORDER BY Frequency DESC;


-- =====================================================================
-- 2. DATA QUALITY CHECKS
-- =====================================================================

-- Duplicate patients (same name and date of birth)
SELECT FirstName, LastName, DOB, COUNT(*) AS DuplicateCount
FROM Patients
GROUP BY FirstName, LastName, DOB
HAVING COUNT(*) > 1;

-- Orphan records: claims pointing to a patient that does not exist
SELECT c.*
FROM Claims c
LEFT JOIN Patients p ON c.PatientID = p.PatientID
WHERE p.PatientID IS NULL;

-- Logical errors: approved amount larger than the amount claimed
SELECT *
FROM Claims
WHERE ApprovedAmount > ClaimAmount;

-- Impossible values: negative amounts or birth dates in the future
SELECT * FROM Claims   WHERE ClaimAmount < 0 OR ApprovedAmount < 0;
SELECT * FROM Patients WHERE DOB > GETDATE();


-- =====================================================================
-- 3. DESCRIPTIVE STATISTICS
-- =====================================================================

-- Summary statistics for ClaimAmount
SELECT
    COUNT(ClaimAmount)            AS N,
    MIN(ClaimAmount)              AS MinValue,
    MAX(ClaimAmount)              AS MaxValue,
    AVG(ClaimAmount)              AS MeanValue,
    STDEV(ClaimAmount)            AS StdDev,
    VAR(ClaimAmount)              AS Variance,
    MAX(ClaimAmount) - MIN(ClaimAmount) AS RangeValue
FROM Claims;

-- Median and quartiles (PERCENTILE_CONT is a window function in SQL Server)
SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS Q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS Median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS Q3
FROM Claims;

-- Mode (most frequent admission reason)
SELECT TOP 1 WITH TIES Reason, COUNT(*) AS Frequency
FROM Admissions
GROUP BY Reason
ORDER BY COUNT(*) DESC;

-- Grouped statistics: claim amounts by policy type
SELECT
    pol.PolicyType,
    COUNT(*)                 AS NumClaims,
    AVG(c.ClaimAmount)       AS AvgClaim,
    STDEV(c.ClaimAmount)     AS StdDevClaim,
    SUM(c.ApprovedAmount)    AS TotalApproved
FROM Claims c
INNER JOIN Policy pol ON c.PolicyID = pol.PolicyID
GROUP BY pol.PolicyType
ORDER BY AvgClaim DESC;

-- Histogram: claim amounts in buckets of 5,000
SELECT
    FLOOR(ClaimAmount / 5000) * 5000        AS BucketStart,
    FLOOR(ClaimAmount / 5000) * 5000 + 4999 AS BucketEnd,
    COUNT(*)                                AS Frequency
FROM Claims
GROUP BY FLOOR(ClaimAmount / 5000)
ORDER BY BucketStart;


-- =====================================================================
-- 4. OUTLIER DETECTION
-- =====================================================================

-- Z-score method: flag claims more than 2 standard deviations from the mean
WITH Stats AS (
    SELECT AVG(ClaimAmount) AS MeanAmt, STDEV(ClaimAmount) AS SdAmt
    FROM Claims
)
SELECT
    c.ClaimID,
    c.ClaimAmount,
    (c.ClaimAmount - s.MeanAmt) / NULLIF(s.SdAmt, 0) AS ZScore
FROM Claims c
CROSS JOIN Stats s
WHERE ABS((c.ClaimAmount - s.MeanAmt) / NULLIF(s.SdAmt, 0)) > 2
ORDER BY ZScore DESC;

-- IQR method: values below Q1 - 1.5*IQR or above Q3 + 1.5*IQR
WITH Quartiles AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ClaimAmount) OVER () AS Q3
    FROM Claims
)
SELECT
    c.ClaimID,
    c.ClaimAmount,
    q.Q1 - 1.5 * (q.Q3 - q.Q1) AS LowerFence,
    q.Q3 + 1.5 * (q.Q3 - q.Q1) AS UpperFence
FROM Claims c
CROSS JOIN Quartiles q
WHERE c.ClaimAmount < q.Q1 - 1.5 * (q.Q3 - q.Q1)
   OR c.ClaimAmount > q.Q3 + 1.5 * (q.Q3 - q.Q1);


-- =====================================================================
-- 5. FEATURE ENGINEERING
-- =====================================================================

-- Patient-level feature table (one row per patient), ready for modelling
WITH ClaimFeatures AS (
    SELECT
        PatientID,
        COUNT(*)                                             AS NumClaims,
        SUM(ClaimAmount)                                     AS TotalClaimed,
        SUM(ApprovedAmount)                                  AS TotalApproved,
        SUM(CASE WHEN ClaimStatus = 'Approved' THEN 1 ELSE 0 END) AS NumApproved
    FROM Claims
    GROUP BY PatientID
),
AdmissionFeatures AS (
    SELECT PatientID, COUNT(*) AS NumAdmissions, MAX(AdmissionDate) AS LastAdmission
    FROM Admissions
    GROUP BY PatientID
)
SELECT
    p.PatientID,
    p.Gender,
    -- Exact age in years
    DATEDIFF(YEAR, p.DOB, GETDATE())
      - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.DOB, GETDATE()), p.DOB) > GETDATE()
             THEN 1 ELSE 0 END                                AS Age,
    -- Binning a numeric variable into categories
    CASE
        WHEN DATEDIFF(YEAR, p.DOB, GETDATE()) < 18 THEN 'Child'
        WHEN DATEDIFF(YEAR, p.DOB, GETDATE()) < 40 THEN 'Young Adult'
        WHEN DATEDIFF(YEAR, p.DOB, GETDATE()) < 65 THEN 'Adult'
        ELSE 'Senior'
    END                                                       AS AgeGroup,
    -- One-hot encoding of Gender
    CASE WHEN p.Gender = 'Female' THEN 1 ELSE 0 END          AS Is_Female,
    CASE WHEN p.Gender = 'Male'   THEN 1 ELSE 0 END          AS Is_Male,
    l.State,
    -- Aggregated behavioural features (missing -> 0)
    ISNULL(cf.NumClaims, 0)                                   AS NumClaims,
    ISNULL(cf.TotalClaimed, 0)                                AS TotalClaimed,
    ISNULL(cf.TotalApproved, 0)                               AS TotalApproved,
    -- Ratio features
    CAST(cf.TotalApproved / NULLIF(cf.TotalClaimed, 0) AS DECIMAL(5,2)) AS ApprovalRatio,
    CAST(1.0 * cf.NumApproved / NULLIF(cf.NumClaims, 0) AS DECIMAL(5,2)) AS ApprovalRate,
    ISNULL(af.NumAdmissions, 0)                               AS NumAdmissions,
    DATEDIFF(DAY, af.LastAdmission, GETDATE())                AS DaysSinceLastAdmission
FROM Patients p
LEFT JOIN Location          l  ON p.LocationID = l.LocationID
LEFT JOIN ClaimFeatures     cf ON p.PatientID  = cf.PatientID
LEFT JOIN AdmissionFeatures af ON p.PatientID  = af.PatientID;

-- Min-max normalisation (scale ClaimAmount to 0-1)
SELECT
    ClaimID,
    ClaimAmount,
    (ClaimAmount - MIN(ClaimAmount) OVER ())
      / NULLIF(MAX(ClaimAmount) OVER () - MIN(ClaimAmount) OVER (), 0) AS ClaimAmount_Scaled
FROM Claims;

-- Standardisation (z-score scaling)
SELECT
    ClaimID,
    ClaimAmount,
    (ClaimAmount - AVG(ClaimAmount) OVER ()) / NULLIF(STDEV(ClaimAmount) OVER (), 0) AS ClaimAmount_Standardised
FROM Claims;

-- Imputation: replace missing ApprovedAmount with the average for that policy
SELECT
    ClaimID,
    PolicyID,
    ApprovedAmount,
    COALESCE(ApprovedAmount, AVG(ApprovedAmount) OVER (PARTITION BY PolicyID)) AS ApprovedAmount_Imputed
FROM Claims;


-- =====================================================================
-- 6. WINDOW FUNCTIONS & RANKING
-- =====================================================================

-- Rank providers by total approved amount
SELECT
    pr.ProviderName,
    SUM(c.ApprovedAmount)                                AS TotalApproved,
    RANK()       OVER (ORDER BY SUM(c.ApprovedAmount) DESC) AS RankPosition,
    DENSE_RANK() OVER (ORDER BY SUM(c.ApprovedAmount) DESC) AS DenseRankPosition
FROM Claims c
INNER JOIN Providers pr ON c.ProviderID = pr.ProviderID
GROUP BY pr.ProviderName;

-- Top 3 most expensive claims per policy type
WITH Ranked AS (
    SELECT
        pol.PolicyType,
        c.ClaimID,
        c.ClaimAmount,
        ROW_NUMBER() OVER (PARTITION BY pol.PolicyType ORDER BY c.ClaimAmount DESC) AS rn
    FROM Claims c
    INNER JOIN Policy pol ON c.PolicyID = pol.PolicyID
)
SELECT PolicyType, ClaimID, ClaimAmount
FROM Ranked
WHERE rn <= 3;

-- Each claim compared with its policy-type average
SELECT
    c.ClaimID,
    pol.PolicyType,
    c.ClaimAmount,
    AVG(c.ClaimAmount) OVER (PARTITION BY pol.PolicyType)                 AS PolicyAvg,
    c.ClaimAmount - AVG(c.ClaimAmount) OVER (PARTITION BY pol.PolicyType) AS DiffFromAvg,
    PERCENT_RANK() OVER (PARTITION BY pol.PolicyType ORDER BY c.ClaimAmount) AS PercentileRank
FROM Claims c
INNER JOIN Policy pol ON c.PolicyID = pol.PolicyID;

-- Pareto analysis: share of total claims covered by the top patients
WITH PatientTotals AS (
    SELECT PatientID, SUM(ClaimAmount) AS TotalClaimed
    FROM Claims
    GROUP BY PatientID
)
SELECT
    PatientID,
    TotalClaimed,
    SUM(TotalClaimed) OVER (ORDER BY TotalClaimed DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
      * 100.0 / SUM(TotalClaimed) OVER ()  AS CumulativePct
FROM PatientTotals
ORDER BY TotalClaimed DESC;


-- =====================================================================
-- 7. TIME SERIES ANALYSIS
-- =====================================================================

-- Monthly admissions with month-over-month change and 3-month moving average
WITH Monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(AdmissionDate), MONTH(AdmissionDate), 1) AS MonthStart,
        COUNT(*) AS Admissions
    FROM Admissions
    GROUP BY DATEFROMPARTS(YEAR(AdmissionDate), MONTH(AdmissionDate), 1)
)
SELECT
    MonthStart,
    Admissions,
    LAG(Admissions) OVER (ORDER BY MonthStart)                  AS PrevMonth,
    Admissions - LAG(Admissions) OVER (ORDER BY MonthStart)     AS MoMChange,
    CAST(100.0 * (Admissions - LAG(Admissions) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(Admissions) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,2)) AS MoMPctChange,
    AVG(1.0 * Admissions) OVER (ORDER BY MonthStart
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg3M,
    SUM(Admissions) OVER (ORDER BY MonthStart
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM Monthly
ORDER BY MonthStart;

-- Seasonality: admissions by day of week
SELECT
    DATENAME(WEEKDAY, AdmissionDate) AS DayOfWeek,
    COUNT(*)                         AS Admissions
FROM Admissions
GROUP BY DATENAME(WEEKDAY, AdmissionDate), DATEPART(WEEKDAY, AdmissionDate)
ORDER BY DATEPART(WEEKDAY, AdmissionDate);

-- 30-day readmissions: patient admitted again within 30 days of a previous admission
WITH Ordered AS (
    SELECT
        PatientID,
        AdmissionID,
        AdmissionDate,
        LAG(AdmissionDate) OVER (PARTITION BY PatientID ORDER BY AdmissionDate) AS PrevAdmissionDate
    FROM Admissions
)
SELECT
    PatientID,
    AdmissionID,
    PrevAdmissionDate,
    AdmissionDate,
    DATEDIFF(DAY, PrevAdmissionDate, AdmissionDate) AS DaysBetween
FROM Ordered
WHERE DATEDIFF(DAY, PrevAdmissionDate, AdmissionDate) <= 30;


-- =====================================================================
-- 8. SEGMENTATION & COHORTS
-- =====================================================================

-- Split patients into 4 equal-sized spending quartiles
WITH PatientTotals AS (
    SELECT PatientID, SUM(ClaimAmount) AS TotalClaimed
    FROM Claims
    GROUP BY PatientID
)
SELECT
    PatientID,
    TotalClaimed,
    NTILE(4) OVER (ORDER BY TotalClaimed DESC) AS SpendQuartile  -- 1 = highest spenders
FROM PatientTotals;

-- RFM-style segmentation (Recency, Frequency, Monetary) using admissions + claims
WITH RFM AS (
    SELECT
        p.PatientID,
        DATEDIFF(DAY, MAX(a.AdmissionDate), GETDATE()) AS Recency,
        COUNT(DISTINCT a.AdmissionID)                  AS Frequency,
        ISNULL(SUM(c.ClaimAmount), 0)                  AS Monetary
    FROM Patients p
    INNER JOIN Admissions a ON p.PatientID = a.PatientID
    LEFT JOIN (
        SELECT PatientID, SUM(ClaimAmount) AS ClaimAmount
        FROM Claims GROUP BY PatientID
    ) c ON p.PatientID = c.PatientID
    GROUP BY p.PatientID
),
Scored AS (
    SELECT *,
        NTILE(3) OVER (ORDER BY Recency DESC)  AS R_Score,  -- 3 = most recent
        NTILE(3) OVER (ORDER BY Frequency)     AS F_Score,
        NTILE(3) OVER (ORDER BY Monetary)      AS M_Score
    FROM RFM
)
SELECT *,
    CASE
        WHEN R_Score + F_Score + M_Score >= 8 THEN 'High Value'
        WHEN R_Score + F_Score + M_Score >= 5 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS Segment
FROM Scored;

-- Cohort analysis: patients grouped by month of first admission,
-- counting how many returned in later months
WITH FirstAdmission AS (
    SELECT PatientID,
           DATEFROMPARTS(YEAR(MIN(AdmissionDate)), MONTH(MIN(AdmissionDate)), 1) AS CohortMonth
    FROM Admissions
    GROUP BY PatientID
),
Activity AS (
    SELECT DISTINCT
        a.PatientID,
        f.CohortMonth,
        DATEDIFF(MONTH, f.CohortMonth, a.AdmissionDate) AS MonthNumber
    FROM Admissions a
    INNER JOIN FirstAdmission f ON a.PatientID = f.PatientID
)
SELECT
    CohortMonth,
    MonthNumber,
    COUNT(*) AS ActivePatients
FROM Activity
GROUP BY CohortMonth, MonthNumber
ORDER BY CohortMonth, MonthNumber;

-- Pivot table: number of claims per policy type by claim status
SELECT PolicyType, [Approved], [Pending], [Rejected]
FROM (
    SELECT pol.PolicyType, c.ClaimStatus, c.ClaimID
    FROM Claims c
    INNER JOIN Policy pol ON c.PolicyID = pol.PolicyID
) AS src
PIVOT (
    COUNT(ClaimID) FOR ClaimStatus IN ([Approved], [Pending], [Rejected])
) AS pvt;


-- =====================================================================
-- 9. CORRELATION
-- =====================================================================

-- Pearson correlation between ClaimAmount and ApprovedAmount
SELECT
    (COUNT(*) * SUM(ClaimAmount * ApprovedAmount) - SUM(ClaimAmount) * SUM(ApprovedAmount))
    / NULLIF(
        SQRT(COUNT(*) * SUM(ClaimAmount * ClaimAmount)       - SQUARE(SUM(ClaimAmount)))
      * SQRT(COUNT(*) * SUM(ApprovedAmount * ApprovedAmount) - SQUARE(SUM(ApprovedAmount)))
      , 0) AS PearsonCorrelation
FROM (
    SELECT CAST(ClaimAmount AS FLOAT) AS ClaimAmount, CAST(ApprovedAmount AS FLOAT) AS ApprovedAmount
    FROM Claims
    WHERE ClaimAmount IS NOT NULL AND ApprovedAmount IS NOT NULL
) t;

-- Simple linear regression: ApprovedAmount = Intercept + Slope * ClaimAmount
WITH Agg AS (
    SELECT
        COUNT(*)                                AS n,
        AVG(CAST(ClaimAmount AS FLOAT))         AS x_bar,
        AVG(CAST(ApprovedAmount AS FLOAT))      AS y_bar
    FROM Claims
    WHERE ClaimAmount IS NOT NULL AND ApprovedAmount IS NOT NULL
)
SELECT
    SUM((c.ClaimAmount - a.x_bar) * (c.ApprovedAmount - a.y_bar))
      / NULLIF(SUM(SQUARE(c.ClaimAmount - a.x_bar)), 0)            AS Slope,
    MAX(a.y_bar) - MAX(a.x_bar)
      * SUM((c.ClaimAmount - a.x_bar) * (c.ApprovedAmount - a.y_bar))
      / NULLIF(SUM(SQUARE(c.ClaimAmount - a.x_bar)), 0)            AS Intercept
FROM Claims c
CROSS JOIN Agg a
WHERE c.ClaimAmount IS NOT NULL AND c.ApprovedAmount IS NOT NULL;


-- =====================================================================
-- 10. TRAIN / TEST SPLIT & SAMPLING
-- =====================================================================

-- Deterministic 80/20 split (same patient always lands in the same set)
SELECT
    PatientID,
    CASE WHEN ABS(CHECKSUM(PatientID)) % 100 < 80 THEN 'Train' ELSE 'Test' END AS DataSplit
FROM Patients;

-- Random sample of 10% of claims
SELECT TOP 10 PERCENT *
FROM Claims
ORDER BY NEWID();

-- Stratified sample: 2 random claims from each claim status
WITH Shuffled AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY ClaimStatus ORDER BY NEWID()) AS rn
    FROM Claims
)
SELECT *
FROM Shuffled
WHERE rn <= 2;
