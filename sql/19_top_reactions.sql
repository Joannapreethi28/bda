-- Upgrade A, step 1: top reaction terms in TRAIN rows only, excluding outcome-leaking terms
CREATE OR REPLACE TABLE faers.top_reactions AS
SELECT UPPER(TRIM(x.reactionmeddrapt)) AS term, COUNT(DISTINCT r.safetyreportid) AS n
FROM faers.drug_event_raw r, UNNEST(r.patient.reaction) x
JOIN faers.train t USING (safetyreportid)
WHERE x.reactionmeddrapt IS NOT NULL
  AND NOT REGEXP_CONTAINS(UPPER(x.reactionmeddrapt), r'DEATH|DIED|FATAL|HOSPITAL|SUICIDE|LIFE THREATENING')
GROUP BY term
ORDER BY n DESC
LIMIT 20;
SELECT * FROM faers.top_reactions ORDER BY n DESC;
