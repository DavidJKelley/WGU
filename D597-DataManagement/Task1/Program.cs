using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using CsvHelper;
using CsvHelper.Configuration;
using Npgsql;

/* 
Install-Package Npgsql -Version 6.0.9        # or latest 6.x that supports .NET Framework
Install-Package CsvHelper -Version 30.0.1    # works on .NET 4.7.2
*/

namespace importdata
{
     
    internal class Program
    {
        // ---- connection string ------------------------------------------------
        private const string Cn = "Host=localhost;Port=5432;Database=D597 Task 1;Username=postgres;Password=AlphaCentauri;Include Error Detail=true";

        // ---- SQL fragments ----------------------------------------------------
        private const string SqlUpsertPatient = @"
                                    INSERT INTO patient (patient_id, first_name, last_name, date_of_birth)
                                    OVERRIDING SYSTEM VALUE
                                    VALUES (@pid, @fn, @ln, @dob)
                                    ON CONFLICT (patient_id) DO UPDATE
                                            SET first_name   = EXCLUDED.first_name,
                                                last_name    = EXCLUDED.last_name,
                                                date_of_birth= EXCLUDED.date_of_birth;";

        private const string SqlInsertMetric = @"
                                    INSERT INTO health_metrics
                                        (patient_id, metric_type_id, metric_value, recorded_date)
                                    VALUES (@pid, @metric_id, @value, NOW());";

        private const string SqlInsertOutcome = @"
                                    INSERT INTO reported_outcomes
                                      (patient_id, outcome_type_id, outcome_text, outcome_date)
                                    VALUES (@pid, @outcome_id, @text, NOW());";

        private const string SqlInsertEhr = @"
                                    INSERT INTO ehr
                                      (patient_id, ehr_type_id, ehr_content)
                                    VALUES (@pid, @ehr_id, @content);";

        private const string SqlInsertAppt = @"
                                    INSERT INTO appointments
                                      (patient_id, appointment_date, appointment_type_id)
                                    VALUES (@pid, @appt_date, @appt_type)
                                    ON CONFLICT DO NOTHING;";

        private const string SqlInsertTracker = @"
                                    INSERT INTO source_definition
                                      (source_type_id, source_name, description, created_date)
                                    VALUES (@src_type, @name, 'Imported tracker', NOW())
                                    ON CONFLICT (source_name) DO UPDATE
                                        SET description = EXCLUDED.description
                                    RETURNING source_id;";

        private const string SqlInsertPatientSource = @"
                                    INSERT INTO patient_source (patient_id, source_id, associated_date)
                                    VALUES (@pid, @src_id, NOW())
                                    ON CONFLICT DO NOTHING;";

        // ---- reference-ID cache ----------------------------------------------
        private static readonly Dictionary<string, int> RefIds = new Dictionary<string, int>();

        // -----------------------------------------------------------------------
        private static void Main(string[] args)
        {
            string csvPath = args.Length > 0 ? args[0] : @"C:\Users\piese\OneDrive\WGU\3.D597 - DataManagement\Scenario 1\Scenario 1\D597 Task 1 Dataset 3_medical_records.csv";

            if (!File.Exists(csvPath))
            {
                Console.WriteLine($"CSV not found: {csvPath}");
                return;
            }

            Console.WriteLine($"Starting import... {csvPath}"); 
            try
            { 
                var csvCfg = new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    TrimOptions = TrimOptions.Trim,
                    HeaderValidated = null,
                    MissingFieldFound = null
                };

                using (var reader = new StreamReader(csvPath))
                using (var csv = new CsvReader(reader, csvCfg))
                {
                    csv.Context.RegisterClassMap<PatientCsvMap>();
                    var records = csv.GetRecords<PatientCsvRecord>();

                    using (var cn = new NpgsqlConnection(Cn))
                    {
                        cn.Open();
                        CacheReferenceIds(cn);

                        using (var tx = cn.BeginTransaction())
                        {
                            // ---- prepare commands once ----------------------------------
                            using (var cmdPatient = new NpgsqlCommand(SqlUpsertPatient, cn, tx))
                            using (var cmdMetric = new NpgsqlCommand(SqlInsertMetric, cn, tx))
                            using (var cmdOutcome = new NpgsqlCommand(SqlInsertOutcome, cn, tx))
                            using (var cmdEhr = new NpgsqlCommand(SqlInsertEhr, cn, tx))
                            using (var cmdAppt = new NpgsqlCommand(SqlInsertAppt, cn, tx))
                            using (var cmdTracker = new NpgsqlCommand(SqlInsertTracker, cn, tx))
                            using (var cmdPatientSource = new NpgsqlCommand(SqlInsertPatientSource, cn, tx))
                            {
                                AddPatientParams(cmdPatient);
                                AddMetricParams(cmdMetric);
                                AddOutcomeParams(cmdOutcome);
                                AddEhrParams(cmdEhr);
                                AddApptParams(cmdAppt);
                                AddTrackerParams(cmdTracker);
                                AddPatientSourceParams(cmdPatientSource);

                                int imported = 0;
                                foreach (var r in records)
                                {
                                    // -------- split name into first / last ------------
                                    var parts = (r.name ?? "").Split(new[] { ' ' }, 2, StringSplitOptions.RemoveEmptyEntries);
                                    string first = parts.Length > 0 ? parts[0] : "";
                                    string last = parts.Length > 1 ? parts[1] : "";

                                    // -------- upsert patient --------------------------
                                    cmdPatient.Parameters["pid"].Value = r.patient_id;
                                    cmdPatient.Parameters["fn"].Value = first;
                                    cmdPatient.Parameters["ln"].Value = last;
                                    cmdPatient.Parameters["dob"].Value = r.date_of_birth.Date;
                                    cmdPatient.ExecuteNonQuery();


                                    // -------- gender  -> metric -----------------------
                                    if (!string.IsNullOrWhiteSpace(r.gender))
                                    {
                                        cmdMetric.Parameters["pid"].Value = r.patient_id;
                                        cmdMetric.Parameters["metric_id"].Value = RefIds["Sex_metric"];
                                        cmdMetric.Parameters["value"].Value = r.gender;
                                        cmdMetric.ExecuteNonQuery();
                                    }

                                    // -------- conditions -> outcome -------------------
                                    if (!string.IsNullOrWhiteSpace(r.medical_conditions))
                                    {
                                        cmdOutcome.Parameters["pid"].Value = r.patient_id;
                                        cmdOutcome.Parameters["outcome_id"].Value = RefIds["Condition_outcome"];
                                        cmdOutcome.Parameters["text"].Value = r.medical_conditions;
                                        cmdOutcome.ExecuteNonQuery();
                                    }

                                    // -------- allergies  -> outcome -------------------
                                    if (!string.IsNullOrWhiteSpace(r.allergies))
                                    {
                                        cmdOutcome.Parameters["pid"].Value = r.patient_id;
                                        cmdOutcome.Parameters["outcome_id"].Value = RefIds["Allergy_outcome"];
                                        cmdOutcome.Parameters["text"].Value = r.allergies;
                                        cmdOutcome.ExecuteNonQuery();
                                    }

                                    // -------- medications -> EHR ----------------------
                                    if (!string.IsNullOrWhiteSpace(r.medications))
                                    {
                                        cmdEhr.Parameters["pid"].Value = r.patient_id;
                                        cmdEhr.Parameters["ehr_id"].Value = RefIds["Prescription_ehr"];
                                        cmdEhr.Parameters["content"].Value = r.medications;
                                        cmdEhr.ExecuteNonQuery();
                                    }

                                    // -------- appointment -----------------------------
                                    cmdAppt.Parameters["pid"].Value = r.patient_id;
                                    cmdAppt.Parameters["appt_date"].Value = r.last_appointment_date;
                                    cmdAppt.Parameters["appt_type"].Value = RefIds["Routine_appt"];
                                    cmdAppt.ExecuteNonQuery();

                                    // -------- tracker -> source_definition ------------
                                    if (!string.IsNullOrWhiteSpace(r.Tracker))
                                    {
                                        cmdTracker.Parameters["src_type"].Value = RefIds["Wearable_src"];
                                        cmdTracker.Parameters["name"].Value = r.Tracker.Trim();

                                        object sourceIdObj = cmdTracker.ExecuteScalar();
                                        int sourceId;

                                        if (sourceIdObj == null || sourceIdObj == DBNull.Value)
                                        {
                                            Console.WriteLine($"Tracker '{r.Tracker}' insert failed or already existed.");
                                            continue; // skip patient_source insert
                                        }
                                        else
                                        {
                                            sourceId = Convert.ToInt32(sourceIdObj);
                                            Console.WriteLine($"Tracker '{r.Tracker}' -> source_id = {sourceId}");
                                        }

                                        // Insert into patient_source
                                        cmdPatientSource.Parameters["pid"].Value = r.patient_id;
                                        cmdPatientSource.Parameters["src_id"].Value = sourceId;
                                        cmdPatientSource.ExecuteNonQuery(); 
                                    }
                                     
                                    imported++;
                                }

                                tx.Commit();
                                Console.WriteLine($"Imported {imported} patients with full detail.");
                            }  
                        }
                    }
                }
            }
            catch (PostgresException pgx)
            {
                Console.WriteLine($"PostgreSQL error: {pgx.MessageText}");
                Console.WriteLine($"Detail        : {pgx.Detail}");
                Console.WriteLine($"Hint          : {pgx.Hint}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Unexpected: {ex}");
            }

            Console.WriteLine("Script Complete.");
            Console.ReadLine();  
        }

        private static void AddPatientSourceParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("src_id", NpgsqlTypes.NpgsqlDbType.Integer);
        }

        // ---------- 3. Reference-ID lookup helpers ------------------------------
        private static void CacheReferenceIds(NpgsqlConnection cn)
        {
            RefIds["Sex_metric"] = GetId(cn, "metric_type", "metric_type_name", "Sex");
            RefIds["Condition_outcome"] = GetId(cn, "outcome_type", "outcome_type_name", "Condition");
            RefIds["Allergy_outcome"] = GetId(cn, "outcome_type", "outcome_type_name", "Alergy");
            RefIds["Prescription_ehr"] = GetId(cn, "ehr_type", "ehr_type_name", "Prescription");
            RefIds["Routine_appt"] = GetId(cn, "appointment_type", "appointment_type_name", "Routine Check-up");
            RefIds["Wearable_src"] = GetId(cn, "source_type", "source_type_name", "Wearable Device");
        }

        private static int GetId(NpgsqlConnection cn, string table, string col, string value)
        {
            using (var cmd = cn.CreateCommand())
            {
                cmd.CommandText = $"SELECT {table}_id FROM {table} WHERE {col} = @v LIMIT 1;";
                cmd.Parameters.AddWithValue("v", value);
                var res = cmd.ExecuteScalar();
                if (res == null)
                    throw new InvalidOperationException($"Missing seed data: {table}.{col} = '{value}'");
                return (int)res;
            }
        }

        // ---------- 4. Parameter helpers (re-used commands) ----------------------
        private static void AddPatientParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("fn", NpgsqlTypes.NpgsqlDbType.Varchar, 100);
            c.Parameters.Add("ln", NpgsqlTypes.NpgsqlDbType.Varchar, 100);
            c.Parameters.Add("dob", NpgsqlTypes.NpgsqlDbType.Date);
        }

        private static void AddMetricParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("metric_id", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("value", NpgsqlTypes.NpgsqlDbType.Varchar, 100);
        }

        private static void AddOutcomeParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("outcome_id", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("text", NpgsqlTypes.NpgsqlDbType.Text);
        }

        private static void AddEhrParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("ehr_id", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("content", NpgsqlTypes.NpgsqlDbType.Text);
        }

        private static void AddApptParams(NpgsqlCommand c)
        {
            c.Parameters.Add("pid", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("appt_date", NpgsqlTypes.NpgsqlDbType.Date);
            c.Parameters.Add("appt_type", NpgsqlTypes.NpgsqlDbType.Integer);
        }

        private static void AddTrackerParams(NpgsqlCommand c)
        {
            c.Parameters.Add("src_type", NpgsqlTypes.NpgsqlDbType.Integer);
            c.Parameters.Add("name", NpgsqlTypes.NpgsqlDbType.Varchar, 255);
        }
    }

    public sealed class PatientCsvRecord
    {
        public int patient_id { get; set; }
        public string name { get; set; }
        public DateTime date_of_birth { get; set; }
        public string gender { get; set; }
        public string medical_conditions { get; set; }
        public string medications { get; set; }
        public string allergies { get; set; }
        public DateTime last_appointment_date { get; set; }
        public string Tracker { get; set; }
    }

    public sealed class PatientCsvMap : ClassMap<PatientCsvRecord>
    {
        public PatientCsvMap()
        {
            AutoMap(CultureInfo.InvariantCulture);
        }
    }
}