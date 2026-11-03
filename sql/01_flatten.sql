-- Step 1: one row per report
CREATE OR REPLACE TABLE faers.reports_flat AS
SELECT
  safetyreportid,
  IF(SAFE_CAST(seriousnesshospitalization AS INT64) = 1
     OR SAFE_CAST(seriousnessdeath AS INT64) = 1, 1, 0)       AS label,
  CASE SAFE_CAST(patient.patientonsetageunit AS INT64)
    WHEN 800 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) * 10
    WHEN 801 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64)
    WHEN 802 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 12
    WHEN 803 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 52
    WHEN 804 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 365
    WHEN 805 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 8760   -- hours (found in Step 0)
  END                                                         AS age_years,
  CAST(patient.patientsex AS STRING)                          AS sex,
  ARRAY_LENGTH(patient.drug)                                  AS n_drugs,
  ARRAY_LENGTH(patient.reaction)                              AS n_reactions,
  (SELECT UPPER(TRIM(d.medicinalproduct))
   FROM UNNEST(patient.drug) d
   WHERE SAFE_CAST(d.drugcharacterization AS INT64) = 1 LIMIT 1) AS suspect_drug
FROM faers.drug_event_raw   -- uploaded openFDA sample (public drug_event table does not exist)
WHERE safetyreportid IS NOT NULL  -- no 5% hash filter: the upload is already a ~1.4% file sample
QUALIFY ROW_NUMBER() OVER (PARTITION BY safetyreportid ORDER BY receivedate DESC) = 1;  -- dedupe report versions
