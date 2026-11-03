-- Step 0 (run on the uploaded raw table): types, label balance inputs, missing age, age-unit codes
SELECT
  COUNT(*)                                                    AS n_rows,
  COUNT(DISTINCT safetyreportid)                              AS n_distinct_ids,
  COUNTIF(SAFE_CAST(seriousnesshospitalization AS INT64) = 1) AS n_hosp,
  COUNTIF(SAFE_CAST(seriousnessdeath AS INT64) = 1)           AS n_death,
  COUNTIF(patient.patientonsetage IS NULL)                    AS n_missing_age,
  COUNTIF(patient.patientsex IS NULL)                         AS n_missing_sex,
  STRING_AGG(DISTINCT patient.patientonsetageunit)            AS age_unit_codes,
  STRING_AGG(DISTINCT patient.patientsex)                     AS sex_codes,
  MIN(receivedate) AS min_date, MAX(receivedate) AS max_date
FROM faers.drug_event_raw;
