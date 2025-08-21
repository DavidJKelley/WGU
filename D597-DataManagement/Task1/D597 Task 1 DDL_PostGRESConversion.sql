-- Create the database
-- CREATE DATABASE healthtrackdb;

-- CREATE DATABASE "D597 Task 1";

-- Run from here to create db structure 

-- db extension... 
CREATE EXTENSION IF NOT EXISTS pgcrypto;
 
 -- conversion from sql server tsql
 
-- Address type reference table (ID is INT)
CREATE TABLE address_type (
    id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    deleted_by VARCHAR(50),
    last_modified_by VARCHAR(50) NOT NULL,
    created_by VARCHAR(50) NOT NULL,
    date_created TIMESTAMP NOT NULL DEFAULT now(),
    last_modified TIMESTAMP NOT NULL DEFAULT now(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create Addresses table (Data) 
CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    line3 VARCHAR(255),
    city VARCHAR(100),
    region VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    type_id INT,
    deleted_by VARCHAR(50),
    last_modified_by VARCHAR(50) NOT NULL,
    created_by VARCHAR(50) NOT NULL,
    date_created TIMESTAMP NOT NULL DEFAULT now(),
    last_modified TIMESTAMP NOT NULL DEFAULT now(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_address_addresstype FOREIGN KEY (type_id) REFERENCES address_type(id)
);

/* ---------- reference table ---------- */
CREATE TABLE alert_type (
    alert_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_type_name VARCHAR(50) NOT NULL
);

/* ---------- data table ---------- */
CREATE TABLE alerts (
    alert_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_message TEXT,
    alert_type_id INT,
    alert_date    TIMESTAMP NOT NULL,
    CONSTRAINT fk_alert_alert_type
        FOREIGN KEY (alert_type_id) REFERENCES alert_type (alert_type_id)
);

-- Create appointment_type table (Reference)
CREATE TABLE appointment_type (
    appointment_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_type_name VARCHAR(50) NOT NULL
);

-- Create appointments table (Data)
CREATE TABLE appointments (
    appointment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INT,
    provider_id INT,
    appointment_date TIMESTAMP NOT NULL,
    appointment_type_id INT,
    CONSTRAINT fk_appointment_appointment_type
        FOREIGN KEY (appointment_type_id)
        REFERENCES appointment_type(appointment_type_id)
);

-- Create contact_value_type table (Reference)
CREATE TABLE contact_value_type (
    contact_value_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contact_value_type_name VARCHAR(50) NOT NULL
);

-- Create contact_values table (Data)
CREATE TABLE contact_values (
    contact_value_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contact_value VARCHAR(255),
    contact_value_type_id INT,
    CONSTRAINT fk_contact_value_contact_value_type
        FOREIGN KEY (contact_value_type_id)
        REFERENCES contact_value_type(contact_value_type_id)
);

-- Create ehr_type table (Reference)
CREATE TABLE ehr_type (
    ehr_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ehr_type_name VARCHAR(50) NOT NULL
);

-- Create ehr table (Data)
CREATE TABLE ehr (
    ehr_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INT,
    ehr_type_id INT,
    ehr_content TEXT,
    CONSTRAINT fk_ehr_ehr_type
        FOREIGN KEY (ehr_type_id)
        REFERENCES ehr_type(ehr_type_id)
);

-- Create metric_type table (Reference)
CREATE TABLE metric_type (
    metric_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metric_type_name VARCHAR(50) NOT NULL
);

-- Create health_metrics table (Data)
CREATE TABLE health_metrics (
    metric_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INT,
    metric_type_id INT,
    metric_value VARCHAR(255),
    recorded_date TIMESTAMP NOT NULL,
    CONSTRAINT fk_health_metrics_metric_type
        FOREIGN KEY (metric_type_id) REFERENCES metric_type(metric_type_id)
);

-- Create insight_type table (Reference)
CREATE TABLE insight_type (
    insight_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    insight_type_name VARCHAR(50) NOT NULL
);

-- Create insights table (Data)
CREATE TABLE insights (
    insight_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id INT,
    patient_id INT,
    insight_type_id INT,
    insight_text TEXT,
    created_date TIMESTAMP NOT NULL,
    CONSTRAINT fk_insights_insight_type
        FOREIGN KEY (insight_type_id) REFERENCES insight_type(insight_type_id)
);


-- Create insurance_providers table (Data)
CREATE TABLE insurance_providers (
    provider_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_name VARCHAR(255) NOT NULL
);

-- Create insurance_plans table (MetaData)
CREATE TABLE insurance_plans (
    plan_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id INT,
    plan_name VARCHAR(255) NOT NULL,
    CONSTRAINT fk_insurance_plans_provider
        FOREIGN KEY (provider_id)
        REFERENCES insurance_providers(provider_id)
);

-- Create location_type table (Reference)
CREATE TABLE location_type (
    location_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    location_type_name VARCHAR(50) NOT NULL
);

-- locations table (Data)
CREATE TABLE locations (
    location_id      INT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    location_name    VARCHAR(255),
    address_id       UUID,                     -- changed from INT ? UUID
    location_type_id INT,
    CONSTRAINT fk_locations_address
        FOREIGN KEY (address_id)      REFERENCES addresses(id),
    CONSTRAINT fk_locations_location_type
        FOREIGN KEY (location_type_id) REFERENCES location_type(location_type_id)
);
 
-- document_type (Reference) 
CREATE TABLE document_type (
    document_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_type_name VARCHAR(50) NOT NULL
);
 
-- meta_document (Data) 
CREATE TABLE meta_document (
    document_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_name    VARCHAR(255),
    document_type_id INT,
    document_url     VARCHAR(1000),
    CONSTRAINT fk_meta_document_document_type
        FOREIGN KEY (document_type_id)
        REFERENCES document_type (document_type_id)
);

-- order_type (Reference)
CREATE TABLE order_type (
    order_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_type_name VARCHAR(50) NOT NULL
);

-- orders (Data) 
CREATE TABLE orders (
    order_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id   INT,
    patient_id    INT,
    order_type_id INT,
    order_details TEXT,
    order_date    TIMESTAMP NOT NULL,
    CONSTRAINT fk_orders_order_type
        FOREIGN KEY (order_type_id)
        REFERENCES order_type (order_type_id)
);

-- patient (Data) 
CREATE TABLE patient (
    patient_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    date_of_birth DATE
);

-- patient_provider (Relational) 
CREATE TABLE patient_provider (
    patient_id  INT,
    provider_id INT,
    PRIMARY KEY (patient_id, provider_id),
    CONSTRAINT fk_patient_provider_patient
        FOREIGN KEY (patient_id)
        REFERENCES patient (patient_id),
    CONSTRAINT fk_patient_provider_provider
        FOREIGN KEY (provider_id)
        REFERENCES insurance_providers (provider_id)
);
 
-- pii (Relational/Data) 
CREATE TABLE pii (
    piiid      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INT,
    pii_value  VARCHAR(255)
);
 
-- pii_addresses (Data)
CREATE TABLE pii_addresses (
    pii_address_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    piiid          INT,
    address_id     UUID,                       -- changed from INT ? UUID
    CONSTRAINT fk_pii_addresses_pii
        FOREIGN KEY (piiid)      REFERENCES pii(piiid),
    CONSTRAINT fk_pii_addresses_address
        FOREIGN KEY (address_id) REFERENCES addresses(id)
);
 
 -- pa_type (Reference)
 CREATE TABLE pa_type (
     pa_type_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     pa_type_name    VARCHAR(100) NOT NULL
 );
 
 -- predictive_analytics (Data) 
 CREATE TABLE predictive_analytics (
     pa_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     patient_id      INT,                     -- FK optional / adjust
     pa_type_id      INT NOT NULL,
     xml_payload     XML      NOT NULL,       -- stores the analysis in XML
     created_date    TIMESTAMP NOT NULL DEFAULT now(),
     CONSTRAINT fk_pa_pa_type
         FOREIGN KEY (pa_type_id) REFERENCES pa_type (pa_type_id),
     CONSTRAINT fk_pa_patient
         FOREIGN KEY (patient_id) REFERENCES patient (patient_id)
 );
 
-- provider Master Table (Data) 
 CREATE TABLE provider (
     provider_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     first_name      VARCHAR(100),
     last_name       VARCHAR(100),
     npi_number      VARCHAR(20),             -- US National Provider Identifier (optional)
     date_created    TIMESTAMP NOT NULL DEFAULT now()
 );
 
 -- credential_type (Reference) 
 CREATE TABLE credential_type (
     credential_type_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     credential_type_name VARCHAR(100) NOT NULL
 );
 
 -- credentials (Data) 
 CREATE TABLE credentials (
     credential_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     provider_id          INT NOT NULL,
     credential_type_id   INT NOT NULL,
     credential_number    VARCHAR(100),
     issued_date          DATE,
     expiry_date          DATE,
     issuing_authority    VARCHAR(255),
     CONSTRAINT fk_credentials_provider
         FOREIGN KEY (provider_id) REFERENCES provider (provider_id),
     CONSTRAINT fk_credentials_type
         FOREIGN KEY (credential_type_id) REFERENCES credential_type (credential_type_id)
 );
  
 -- accepted_insurance (Relational)
 CREATE TABLE accepted_insurance (
     provider_id          INT,
     insurance_provider_id INT,
     plan_id              INT,          -- nullable: provider accepts the whole carrier, or a specific plan 
     accepted_insurance_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
     CONSTRAINT fk_ai_provider
         FOREIGN KEY (provider_id) REFERENCES provider (provider_id),
     CONSTRAINT fk_ai_insurance_provider
         FOREIGN KEY (insurance_provider_id) REFERENCES insurance_providers (provider_id),
     CONSTRAINT fk_ai_plan
         FOREIGN KEY (plan_id) REFERENCES insurance_plans (plan_id)
 );
 
 -- provider_contact_values (Relational) 
 CREATE TABLE provider_contact_values (
     provider_id      INT,
     contact_value_id INT,
     PRIMARY KEY (provider_id, contact_value_id),
     CONSTRAINT fk_pcv_provider
         FOREIGN KEY (provider_id) REFERENCES provider (provider_id),
     CONSTRAINT fk_pcv_contact_value
         FOREIGN KEY (contact_value_id) REFERENCES contact_values (contact_value_id)
 );
 
-- provider_locations (Relational) 
CREATE TABLE provider_locations (
     provider_id  INT,
     location_id  INT,
     PRIMARY KEY (provider_id, location_id),
     CONSTRAINT fk_pl_provider
         FOREIGN KEY (provider_id) REFERENCES provider (provider_id),
     CONSTRAINT fk_pl_location
         FOREIGN KEY (location_id) REFERENCES locations (location_id)
 );
 
-- reading_type (Reference) 
CREATE TABLE reading_type (
    reading_type_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reading_type_name VARCHAR(100) NOT NULL
);

-- reading (Data) -- high traffic?  
CREATE TABLE reading (
    reading_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id        INT NOT NULL,
    reading_type_id   INT NOT NULL,
    reading_value     VARCHAR(255),
    reading_unit      VARCHAR(50),
    reading_timestamp TIMESTAMP NOT NULL,
    CONSTRAINT fk_reading_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_reading_type
        FOREIGN KEY (reading_type_id) REFERENCES reading_type (reading_type_id)
); 

-- outcome_type (Reference)
CREATE TABLE outcome_type (
    outcome_type_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outcome_type_name VARCHAR(100) NOT NULL
);

-- reported_outcomes (Data) 
CREATE TABLE reported_outcomes (
    outcome_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id        INT NOT NULL,
    provider_id       INT,
    outcome_type_id   INT NOT NULL,
    outcome_text      TEXT,
    outcome_date      TIMESTAMP NOT NULL,
    CONSTRAINT fk_outcomes_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_outcomes_provider
        FOREIGN KEY (provider_id) REFERENCES provider (provider_id),
    CONSTRAINT fk_outcomes_type
        FOREIGN KEY (outcome_type_id) REFERENCES outcome_type (outcome_type_id)
);
 
-- security_log_type (Reference) 
CREATE TABLE security_log_type (
    security_log_type_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    security_log_type_name VARCHAR(100) NOT NULL
);

-- security_log (Data) high traffic
CREATE TABLE security_log ( 
    security_log_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    security_log_type_id INT NOT NULL,
    user_id              INT,            -- nullable if event not user-initiated
    log_timestamp        TIMESTAMP NOT NULL DEFAULT now(),
    source_ip            INET,
    details              TEXT,
    CONSTRAINT fk_security_log_type
        FOREIGN KEY (security_log_type_id) REFERENCES security_log_type (security_log_type_id)
    -- user_id FK added below after users table is created
); 

-- source_type (Reference) 
CREATE TABLE source_type (
    source_type_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_type_name VARCHAR(100) NOT NULL
);

-- source_definition master (Data) 
CREATE TABLE source_definition (
    source_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_type_id   INT NOT NULL,
    source_name      VARCHAR(255) NOT NULL,
    manufacturer     VARCHAR(255),
    model            VARCHAR(255),
    description      TEXT,
    created_date     TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_source_type
        FOREIGN KEY (source_type_id) REFERENCES source_type (source_type_id)
);

-- users master (Data) 
CREATE TABLE users (
    user_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    email         VARCHAR(255),
    date_created  TIMESTAMP NOT NULL DEFAULT now(),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

-- now tie user FK into security_log
ALTER TABLE security_log
    ADD CONSTRAINT fk_security_log_user
        FOREIGN KEY (user_id) REFERENCES users (user_id);
        
ALTER TABLE source_definition
	ADD CONSTRAINT uq_source_definition_name UNIQUE (source_name);

CREATE TABLE patient_source (
    patient_source_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id        INT NOT NULL,
    source_id         INT NOT NULL,
    associated_date   TIMESTAMP NOT NULL DEFAULT now(),
    notes             TEXT,

    CONSTRAINT fk_patient_source_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),

    CONSTRAINT fk_patient_source_definition
        FOREIGN KEY (source_id) REFERENCES source_definition (source_id)
);

/* ------------------------------------------------------------------
   SEED DATA FOR REFERENCE TABLES
------------------------------------------------------------------ */

BEGIN;   

/* ---------- address_type ---------------------------------------- */
INSERT INTO address_type (name, description, last_modified_by, created_by)
VALUES
  ('Home',     'Primary residential address',            'seed','seed'),
  ('Work',     'Employer or business address',           'seed','seed'),
  ('Billing',  'Address used for billing statements',    'seed','seed'),
  ('Shipping', 'Address used for shipping/receiving',    'seed','seed'),
  ('Other',    'Any other address category',             'seed','seed');

/* ---------- alert_type ------------------------------------------ */
INSERT INTO alert_type (alert_type_name) VALUES
  ('Information'),
  ('Warning'),
  ('Critical'),
  ('Success');

/* ---------- appointment_type ------------------------------------ */
INSERT INTO appointment_type (appointment_type_name) VALUES
  ('Routine Check-up'),
  ('Follow-up'),
  ('Emergency'),
  ('Telemedicine'),
  ('Consultation');

/* ---------- contact_value_type ---------------------------------- */
INSERT INTO contact_value_type (contact_value_type_name) VALUES
  ('Mobile Phone'),
  ('Home Phone'),
  ('Work Phone'),
  ('Email'),
  ('Fax'),
  ('Pager'),
  ('Website');

/* ---------- ehr_type -------------------------------------------- */
INSERT INTO ehr_type (ehr_type_name) VALUES
  ('Clinical Note'),
  ('Lab Result'),
  ('Radiology Image'),
  ('Prescription'),
  ('Discharge Summary');

/* ---------- metric_type ----------------------------------------- */
INSERT INTO metric_type (metric_type_name) VALUES
  ('Weight'),
  ('Height'),
  ('Body-Mass Index'),
  ('Body Temperature'),
  ('Blood Pressure – Systolic'),
  ('Blood Pressure – Diastolic'),
  ('Heart Rate'),
  ('Blood Glucose'),
  ('Oxygen Saturation'),
  ('Respiratory Rate'),
  ('Sex');

/* ---------- insight_type ---------------------------------------- */
INSERT INTO insight_type (insight_type_name) VALUES
  ('Care-plan Recommendation'),
  ('Medication Adjustment'),
  ('Lifestyle Advice'),
  ('Risk Alert'),
  ('Follow-up Needed');

/* ---------- location_type --------------------------------------- */
INSERT INTO location_type (location_type_name) VALUES
  ('Hospital'),
  ('Clinic'),
  ('Laboratory'),
  ('Imaging Center'),
  ('Pharmacy'),
  ('Urgent Care'),
  ('Telehealth');

/* ---------- document_type --------------------------------------- */
INSERT INTO document_type (document_type_name) VALUES
  ('PDF'),
  ('HL7'),
  ('CCD'),
  ('DICOM'),
  ('Image'),
  ('Text');

/* ---------- order_type ------------------------------------------ */
INSERT INTO order_type (order_type_name) VALUES
  ('Lab Test'),
  ('Imaging Study'),
  ('Medication Prescription'),
  ('Referral'),
  ('Procedure'),
  ('Vaccination');

/* ---------- pa_type --------------------------------------------- */
INSERT INTO pa_type (pa_type_name) VALUES
  ('Risk Score'),
  ('Predictive Model'),
  ('Treatment Recommendation'),
  ('Adherence Alert'),
  ('Readmission Probability');

/* ---------- credential_type ------------------------------------- */
INSERT INTO credential_type (credential_type_name) VALUES
  ('Medical License'),
  ('Board Certification'),
  ('DEA Registration'),
  ('State License'),
  ('Nursing License'),
  ('Specialty Certification');

/* ---------- reading_type ---------------------------------------- */
INSERT INTO reading_type (reading_type_name) VALUES
  ('Heart Rate'),
  ('Blood Pressure'),
  ('Blood Glucose'),
  ('Body Temperature'),
  ('Oxygen Saturation'),
  ('Respiratory Rate'),
  ('Weight');

/* ---------- outcome_type ---------------------------------------- */
INSERT INTO outcome_type (outcome_type_name) VALUES
  ('Patient-reported Outcome'),
  ('Clinical Outcome'),
  ('Adverse Event'),
  ('Readmission'),
  ('Mortality'),
  ('Quality of Life'), 
  ('Condition'), 
  ('Alergy');

/* ---------- security_log_type ----------------------------------- */
INSERT INTO security_log_type (security_log_type_name) VALUES
  ('Login Success'),
  ('Login Failure'),
  ('Password Change'),
  ('Role Assignment'),
  ('Data Access'),
  ('Data Modification'),
  ('Account Lockout'),
  ('System Error');

/* ---------- source_type ----------------------------------------- */
INSERT INTO source_type (source_type_name) VALUES
  ('Wearable Device'),
  ('EHR Integration'),
  ('Lab Analyzer'),
  ('Imaging Device'),
  ('Mobile App'),
  ('Manual Entry'),
  ('Pharmacy System'), 
  ('Device');

COMMIT;
