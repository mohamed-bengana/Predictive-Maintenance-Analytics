-- Check missing critical fields
SELECT 
    COUNT(*) as total_records,
    COUNT(record_id) as records_with_id,
    COUNT(equipment_id) as records_with_equipment,
    COUNT(timestamp) as records_with_timestamp,
    COUNT(temperature_c) as records_with_temp,
    COUNT(vibration_mm_s) as records_with_vibration,
    COUNT(pressure_bar) as records_with_pressure,
    COUNT(failure_flag) as records_with_failure_flag
FROM predictive_maintenance;

-- Identify records with NULL critical sensor values
SELECT 
    record_id, 
    equipment_id, 
    timestamp,
    temperature_c,
    vibration_mm_s,
    pressure_bar
FROM predictive_maintenance
WHERE temperature_c IS NULL 
   OR vibration_mm_s IS NULL 
   OR pressure_bar IS NULL
   OR rpm IS NULL;

-- Find duplicate records
SELECT 
    equipment_id, 
    timestamp, 
    COUNT(*) as duplicate_count
FROM predictive_maintenance
GROUP BY equipment_id, timestamp
HAVING COUNT(*) > 1;

-- Check for duplicate record IDs
SELECT record_id, COUNT(*) as count
FROM predictive_maintenance
GROUP BY record_id
HAVING COUNT(*) > 1;

-- Check for negative or unrealistic sensor values
SELECT 
    record_id,
    equipment_id,
    temperature_c,
    vibration_mm_s,
    pressure_bar,
    rpm,
    load_percent
FROM predictive_maintenance
WHERE temperature_c < -50 OR temperature_c > 200
   OR vibration_mm_s < 0 OR vibration_mm_s > 100
   OR pressure_bar < 0 OR pressure_bar > 500
   OR rpm < 0
   OR load_percent < 0 OR load_percent > 100;

-- Check for illogical operating hours
SELECT 
    record_id,
    equipment_id,
    operating_hours,
    efficiency_percent
FROM predictive_maintenance
WHERE operating_hours < 0
   OR efficiency_percent < 0 OR efficiency_percent > 100;

-- Verify failure_flag consistency
SELECT 
    record_id,
    failure_flag,
    failure_type,
    downtime_minutes
FROM predictive_maintenance
WHERE (failure_flag = 1 AND failure_type IS NULL)
   OR (failure_flag = 0 AND downtime_minutes > 0)
   OR (failure_flag = 1 AND downtime_minutes IS NULL);


-- Statistical outliers for temperature
WITH temp_stats AS (
    SELECT 
        AVG(temperature_c) as mean_temp,
        STDEV(temperature_c) as std_temp
    FROM predictive_maintenance
    WHERE temperature_c IS NOT NULL
)
SELECT 
    p.record_id,
    p.equipment_id,
    p.temperature_c,
    s.mean_temp,
    ABS(p.temperature_c - s.mean_temp) / s.std_temp as z_score
FROM predictive_maintenance p
CROSS JOIN temp_stats s
WHERE ABS(p.temperature_c - s.mean_temp) / s.std_temp > 3;

-- Vibration outliers
WITH vib_stats AS (
    SELECT 
        equipment_type,
        AVG(vibration_mm_s) as mean_vib,
        STDEV(vibration_mm_s) as std_vib
    FROM predictive_maintenance
    WHERE vibration_mm_s IS NOT NULL
    GROUP BY equipment_type
)
SELECT 
    p.record_id,
    p.equipment_id,
    p.equipment_type,
    p.vibration_mm_s,
    v.mean_vib,
    ABS(p.vibration_mm_s - v.mean_vib) / v.std_vib as z_score
FROM predictive_maintenance p
JOIN vib_stats v ON p.equipment_type = v.equipment_type
WHERE ABS(p.vibration_mm_s - v.mean_vib) / v.std_vib > 3;