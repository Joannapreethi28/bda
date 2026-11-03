-- Upgrade B: time-based split. Oldest ~80% of reports (by receivedate) = train, newest ~20% = test.
CREATE OR REPLACE TABLE faers.time_cutoff AS
SELECT APPROX_QUANTILES(receivedate, 10)[OFFSET(8)] AS cutoff
FROM faers.drug_event_raw;

CREATE OR REPLACE TABLE faers.reports_dated AS
SELECT f.*, r.receivedate
FROM faers.reports_flat f
JOIN (SELECT safetyreportid, MAX(receivedate) AS receivedate FROM faers.drug_event_raw GROUP BY 1) r
USING (safetyreportid);

-- top-30 drugs picked from the TIME-train rows only
CREATE OR REPLACE TABLE faers.top_drugs_time AS
SELECT suspect_drug, COUNT(*) AS n FROM faers.reports_dated
WHERE receivedate < (SELECT cutoff FROM faers.time_cutoff) AND suspect_drug IS NOT NULL
GROUP BY 1 ORDER BY n DESC LIMIT 30;

CREATE OR REPLACE TABLE faers.train_time AS
SELECT r.safetyreportid, r.receivedate, r.label,
       IF(r.age_years BETWEEN 0 AND 120, r.age_years, NULL) AS age_years,
       IFNULL(r.sex, 'UNK') AS sex, r.n_drugs, r.n_reactions,
       IFNULL(t.suspect_drug, 'OTHER') AS drug_group
FROM faers.reports_dated r LEFT JOIN faers.top_drugs_time t USING (suspect_drug)
WHERE r.receivedate < (SELECT cutoff FROM faers.time_cutoff);

CREATE OR REPLACE TABLE faers.test_time AS
SELECT r.safetyreportid, r.receivedate, r.label,
       IF(r.age_years BETWEEN 0 AND 120, r.age_years, NULL) AS age_years,
       IFNULL(r.sex, 'UNK') AS sex, r.n_drugs, r.n_reactions,
       IFNULL(t.suspect_drug, 'OTHER') AS drug_group
FROM faers.reports_dated r LEFT JOIN faers.top_drugs_time t USING (suspect_drug)
WHERE r.receivedate >= (SELECT cutoff FROM faers.time_cutoff);

SELECT (SELECT cutoff FROM faers.time_cutoff) AS cutoff,
       (SELECT COUNT(*) FROM faers.train_time) AS n_train, (SELECT ROUND(AVG(label),3) FROM faers.train_time) AS train_serious,
       (SELECT MIN(receivedate) FROM faers.train_time) AS train_from,
       (SELECT COUNT(*) FROM faers.test_time) AS n_test, (SELECT ROUND(AVG(label),3) FROM faers.test_time) AS test_serious,
       (SELECT MAX(receivedate) FROM faers.test_time) AS test_to;
