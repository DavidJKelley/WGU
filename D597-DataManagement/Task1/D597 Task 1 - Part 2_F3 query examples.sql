-- query examples: 

-- 1. Patient
SELECT * FROM patient
WHERE patient_id = 1;

-- 2. Appointments
SELECT a.*, at.appointment_type_name
FROM appointments a
LEFT JOIN appointment_type at ON a.appointment_type_id = at.appointment_type_id
WHERE a.patient_id = 1;

-- 3. Health Metrics
SELECT hm.*, mt.metric_type_name
FROM health_metrics hm
LEFT JOIN metric_type mt ON hm.metric_type_id = mt.metric_type_id
WHERE hm.patient_id = 1;

-- 4. Reported Outcomes
SELECT ro.*, ot.outcome_type_name
FROM reported_outcomes ro
LEFT JOIN outcome_type ot ON ro.outcome_type_id = ot.outcome_type_id
WHERE ro.patient_id = 1;

-- 5. EHR Entries
SELECT e.*, et.ehr_type_name
FROM ehr e
LEFT JOIN ehr_type et ON e.ehr_type_id = et.ehr_type_id
WHERE e.patient_id = 1;

-- 6. Insights
SELECT i.*, it.insight_type_name
FROM insights i
LEFT JOIN insight_type it ON i.insight_type_id = it.insight_type_id
WHERE i.patient_id = 1;

-- 7. Orders
SELECT o.*, ot.order_type_name
FROM orders o
LEFT JOIN order_type ot ON o.order_type_id = ot.order_type_id
WHERE o.patient_id = 1;

-- 8. PII and PII Addresses
SELECT pii.*, pa.pii_address_id, a.*
FROM pii
LEFT JOIN pii_addresses pa ON pii.piiid = pa.piiid
LEFT JOIN addresses a ON pa.address_id = a.id
WHERE pii.patient_id = 1;

-- 9. Patient Providers
SELECT pp.*, ip.provider_name
FROM patient_provider pp
LEFT JOIN insurance_providers ip ON pp.provider_id = ip.provider_id
WHERE pp.patient_id = 1;

-- 10. Readings
SELECT r.*, rt.reading_type_name
FROM reading r
LEFT JOIN reading_type rt ON r.reading_type_id = rt.reading_type_id
WHERE r.patient_id = 1;

-- all the sources for a specific patient
SELECT 
    sd.source_id,
    sd.source_name,
    sd.manufacturer,
    sd.model,
    sd.description,
    sd.created_date,
    st.source_type_name,
    ps.associated_date,
    ps.notes
FROM 
    patient_source ps
JOIN 
    source_definition sd ON ps.source_id = sd.source_id
JOIN 
    source_type st ON sd.source_type_id = st.source_type_id
WHERE 
    ps.patient_id = 2;

-- all the patiences using a specific device
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    sd.source_name,
    st.source_type_name,
    ps.associated_date
FROM 
    patient_source ps
JOIN 
    patient p ON ps.patient_id = p.patient_id
JOIN 
    source_definition sd ON ps.source_id = sd.source_id
JOIN 
    source_type st ON sd.source_type_id = st.source_type_id
WHERE 
    sd.source_name ILIKE 'Band 4';  

-- patient record... 
WITH patient_info AS (
    SELECT 
        p.patient_id,
        p.first_name,
        p.last_name,
        p.date_of_birth
    FROM patient p
    WHERE p.patient_id = 2
)

SELECT 
    pi.patient_id,
    pi.first_name,
    pi.last_name,
    pi.date_of_birth,

    -- Health Metrics
    hm.metric_id,
    mt.metric_type_name,
    hm.metric_value,
    hm.recorded_date,

    -- Reported Outcomes
    ro.outcome_id,
    ot.outcome_type_name,
    ro.outcome_text,
    ro.outcome_date,

    -- Predictive Analytics
    pa.pa_id,
    pt.pa_type_name,
    pa.xml_payload AS predictive_xml,
    pa.created_date AS predictive_created,

    -- EHR Records
    ehr.ehr_id,
    eht.ehr_type_name,
    ehr.ehr_content,

    -- Clinical Insights
    ins.insight_id,
    it.insight_type_name,
    ins.insight_text,
    ins.created_date AS insight_created,

    -- Sensor Readings
    r.reading_id,
    rt.reading_type_name,
    r.reading_value,
    r.reading_unit,
    r.reading_timestamp

FROM patient_info pi

-- Health Metrics
LEFT JOIN health_metrics hm ON pi.patient_id = hm.patient_id
LEFT JOIN metric_type mt ON hm.metric_type_id = mt.metric_type_id

-- Reported Outcomes
LEFT JOIN reported_outcomes ro ON pi.patient_id = ro.patient_id
LEFT JOIN outcome_type ot ON ro.outcome_type_id = ot.outcome_type_id

-- Predictive Analytics
LEFT JOIN predictive_analytics pa ON pi.patient_id = pa.patient_id
LEFT JOIN pa_type pt ON pa.pa_type_id = pt.pa_type_id

-- EHR
LEFT JOIN ehr ehr ON pi.patient_id = ehr.patient_id
LEFT JOIN ehr_type eht ON ehr.ehr_type_id = eht.ehr_type_id

-- Insights
LEFT JOIN insights ins ON pi.patient_id = ins.patient_id
LEFT JOIN insight_type it ON ins.insight_type_id = it.insight_type_id

-- Readings
LEFT JOIN reading r ON pi.patient_id = r.patient_id
LEFT JOIN reading_type rt ON r.reading_type_id = rt.reading_type_id

ORDER BY pi.patient_id, hm.recorded_date NULLS LAST, ro.outcome_date NULLS LAST;


-- readings report
SELECT 
    r.reading_id,
    r.patient_id,
    p.first_name,
    p.last_name,
    rt.reading_type_name,
    r.reading_value,
    r.reading_unit,
    r.reading_timestamp
FROM 
    reading r
JOIN 
    reading_type rt ON r.reading_type_id = rt.reading_type_id
JOIN 
    patient p ON r.patient_id = p.patient_id
WHERE 
    r.patient_id = 2   
ORDER BY 
    r.reading_timestamp DESC;

-- Optimized 1
EXPLAIN ANALYZE 
SELECT 
    r.reading_id,
    r.patient_id, 
    r.reading_value,
    r.reading_unit,
    r.reading_timestamp
FROM 
    reading r 
WHERE 
    r.patient_id = 2
ORDER BY 
    r.reading_timestamp DESC
LIMIT 100 ;

-- add a composite index
CREATE INDEX idx_reading_patient_timestamp_desc ON reading (patient_id, reading_timestamp DESC);
CREATE INDEX idx_reading_reading_type_id ON reading (reading_type_id);
CREATE INDEX idx_reading_patient_id ON reading (patient_id);

-- second optimized query: 

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,

    -- Health Metrics
    hm.metric_id,
    mt.metric_type_name,
    hm.metric_value,
    hm.recorded_date,

    -- Reported Outcomes
    ro.outcome_id,
    ot.outcome_type_name,
    ro.outcome_text,
    ro.outcome_date,

    -- Predictive Analytics
    pa.pa_id,
    pt.pa_type_name,
    pa.xml_payload AS predictive_xml,
    pa.created_date AS predictive_created,

    -- EHR Records
    ehr.ehr_id,
    eht.ehr_type_name,
    ehr.ehr_content,

    -- Clinical Insights
    ins.insight_id,
    it.insight_type_name,
    ins.insight_text,
    ins.created_date AS insight_created,

    -- Sensor Readings
    r.reading_id,
    rt.reading_type_name,
    r.reading_value,
    r.reading_unit,
    r.reading_timestamp

FROM patient p

-- Health Metrics
LEFT JOIN health_metrics hm ON p.patient_id = hm.patient_id
LEFT JOIN metric_type mt ON hm.metric_type_id = mt.metric_type_id

-- Reported Outcomes
LEFT JOIN reported_outcomes ro ON p.patient_id = ro.patient_id
LEFT JOIN outcome_type ot ON ro.outcome_type_id = ot.outcome_type_id

-- Predictive Analytics
LEFT JOIN predictive_analytics pa ON p.patient_id = pa.patient_id
LEFT JOIN pa_type pt ON pa.pa_type_id = pt.pa_type_id

-- EHR
LEFT JOIN ehr ehr ON p.patient_id = ehr.patient_id
LEFT JOIN ehr_type eht ON ehr.ehr_type_id = eht.ehr_type_id

-- Insights
LEFT JOIN insights ins ON p.patient_id = ins.patient_id
LEFT JOIN insight_type it ON ins.insight_type_id = it.insight_type_id

-- Readings
LEFT JOIN reading r ON p.patient_id = r.patient_id
LEFT JOIN reading_type rt ON r.reading_type_id = rt.reading_type_id

WHERE p.patient_id = 2
ORDER BY hm.recorded_date NULLS LAST, ro.outcome_date NULLS LAST;


-- index's to help that one... 
CREATE INDEX idx_patient_id ON patient (patient_id);
CREATE INDEX idx_health_metrics_patient_date ON health_metrics (patient_id, recorded_date);
CREATE INDEX idx_reported_outcomes_patient_date ON reported_outcomes (patient_id, outcome_date);
CREATE INDEX idx_predictive_analytics_patient_date ON predictive_analytics (patient_id, created_date);
CREATE INDEX idx_reading_patient_date ON reading (patient_id, reading_timestamp);
CREATE INDEX idx_health_metrics_metric_type_id ON health_metrics (metric_type_id);
CREATE INDEX idx_reported_outcomes_outcome_type_id ON reported_outcomes (outcome_type_id);
CREATE INDEX idx_ehr_ehr_type_id ON ehr (ehr_type_id);
CREATE INDEX idx_insights_insight_type_id ON insights (insight_type_id);
--CREATE INDEX idx_reading_reading_type_id ON reading (reading_type_id);


-- optimized query: 
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    sd.source_name,
    st.source_type_name,
    ps.associated_date
FROM 
    patient_source ps
JOIN 
    patient p ON ps.patient_id = p.patient_id
JOIN 
    source_definition sd ON ps.source_id = sd.source_id
JOIN 
    source_type st ON sd.source_type_id = st.source_type_id
WHERE 
    LOWER(sd.source_name) = 'band 4';



CREATE INDEX idx_source_definition_lower_name
ON source_definition (LOWER(source_name));
CREATE INDEX idx_patient_source_patient_id ON patient_source (patient_id);
CREATE INDEX idx_patient_source_source_id ON patient_source (source_id);
CREATE INDEX idx_source_definition_source_type_id ON source_definition (source_type_id);
