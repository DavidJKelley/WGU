------------------------------------
-- patient 2 unit test data

-- Source data... 
INSERT INTO source_definition (source_type_id, source_name, manufacturer, model, description, created_date)
SELECT st.source_type_id, 'Band 3', 'TestWear', 'BW3', 'Test Band 3 Wearable', now()
FROM source_type st
WHERE st.source_type_name = 'Wearable Device'
ON CONFLICT (source_name) DO NOTHING;

WITH src AS (
    SELECT source_id FROM source_definition WHERE source_name = 'Band 3'
)

INSERT INTO patient_source (patient_id, source_id)
SELECT 2, src.source_id FROM src
ON CONFLICT DO NOTHING;

-- predictive analytics
INSERT INTO predictive_analytics (patient_id, pa_type_id, xml_payload, created_date)
SELECT 
    2,
    pt.pa_type_id,
    '<prediction><risk>low</risk><recommendation>continue current medication</recommendation></prediction>'::xml,
    now()
FROM pa_type pt
WHERE pt.pa_type_name = 'Predictive Model'
LIMIT 1;

-- insights
INSERT INTO insights (patient_id, provider_id, insight_type_id, insight_text, created_date)
SELECT 
    2,
    1,  -- provider_id, adjust if needed
    it.insight_type_id,
    'Patient is responding well to current treatment plan.',
    now()
FROM insight_type it
WHERE it.insight_type_name = 'Care-plan Recommendation'
LIMIT 1;

INSERT INTO insights (patient_id, provider_id, insight_type_id, insight_text, created_date)
SELECT 
    2,
    1,
    it.insight_type_id,
    'Consider increasing physical activity levels.',
    now()
FROM insight_type it
WHERE it.insight_type_name = 'Lifestyle Advice'
LIMIT 1;

-- readings data
DO $$
DECLARE 
    i INT;
    rid INT;
BEGIN
    SELECT reading_type_id INTO rid FROM reading_type WHERE reading_type_name = 'Heart Rate' LIMIT 1;

    FOR i IN 1..10 LOOP
        INSERT INTO reading (
            patient_id,
            reading_type_id,
            reading_value,
            reading_unit,
            reading_timestamp
        ) VALUES (
            2,
            rid,
            (60 + random() * 30)::INT::TEXT,
            'bpm',
            now() - (i || ' hours')::interval
        );
    END LOOP;
END $$;
