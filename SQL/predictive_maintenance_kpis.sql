-- Overall failure rate
SELECT 
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as total_failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct
FROM predictive_maintenance;

-- Failure rate by equipment type
SELECT 
    equipment_type,
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct
FROM predictive_maintenance
GROUP BY equipment_type
ORDER BY failure_rate_pct DESC;

-- Failure rate by equipment
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct
FROM predictive_maintenance
GROUP BY equipment_id, equipment_type, plant_area
ORDER BY failure_rate_pct DESC;

-- Monthly failure rate trend
SELECT 
    YEAR(date) as year,
    MONTH(date) as month,
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct
FROM predictive_maintenance
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;

-- Failure rate by shift
SELECT 
    shift,
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct
FROM predictive_maintenance
GROUP BY shift
ORDER BY failure_rate_pct DESC;

-- MTBF calculation in hours
-- Method 1: Using operating hours
WITH failure_events AS (
    SELECT 
        equipment_id,
        equipment_type,
        timestamp,
        operating_hours,
        ROW_NUMBER() OVER (PARTITION BY equipment_id ORDER BY timestamp) as failure_num
    FROM predictive_maintenance
    WHERE failure_flag = 1
),
time_between_failures AS (
    SELECT 
        f1.equipment_id,
        f1.equipment_type,
        f1.operating_hours - COALESCE(f2.operating_hours, 0) as hours_between_failures
    FROM failure_events f1
    LEFT JOIN failure_events f2 
        ON f1.equipment_id = f2.equipment_id 
        AND f2.failure_num = f1.failure_num - 1
    WHERE f1.failure_num > 1
)
SELECT 
    equipment_id,
    equipment_type,
    COUNT(*) as failure_intervals,
    AVG(hours_between_failures) as mtbf_hours,
    MIN(hours_between_failures) as min_time_between_failures,
    MAX(hours_between_failures) as max_time_between_failures,
    STDEV(hours_between_failures) as std_dev_hours
FROM time_between_failures
GROUP BY equipment_id, equipment_type
ORDER BY mtbf_hours;

-- Method 2: Simplified MTBF by equipment type
SELECT 
    equipment_type,
    SUM(operating_hours) as total_operating_hours,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as total_failures,
    CAST(SUM(operating_hours) / NULLIF(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) as mtbf_hours
FROM predictive_maintenance
GROUP BY equipment_type
ORDER BY mtbf_hours DESC;

-- MTBF by plant area
SELECT 
    plant_area,
    equipment_type,
    SUM(operating_hours) as total_operating_hours,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as total_failures,
    CAST(SUM(operating_hours) / NULLIF(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) as mtbf_hours
FROM predictive_maintenance
GROUP BY plant_area, equipment_type
ORDER BY mtbf_hours DESC;

-- MTTR in minutes
SELECT 
    equipment_type,
    COUNT(*) as total_failures,
    AVG(downtime_minutes) as mttr_minutes,
    MIN(downtime_minutes) as min_downtime,
    MAX(downtime_minutes) as max_downtime,
    STDEV(downtime_minutes) as std_dev_minutes,
    CAST(AVG(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as mttr_hours
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_type
ORDER BY mttr_minutes DESC;

-- MTTR by equipment
SELECT 
    equipment_id,
    equipment_type,
    manufacturer,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as mttr_minutes,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(AVG(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as mttr_hours
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_id, equipment_type, manufacturer
ORDER BY mttr_minutes DESC;

-- MTTR by failure type
SELECT 
    failure_type,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as mttr_minutes,
    MIN(downtime_minutes) as min_repair_time,
    MAX(downtime_minutes) as max_repair_time,
    CAST(AVG(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as mttr_hours
FROM predictive_maintenance
WHERE failure_flag = 1 
  AND downtime_minutes IS NOT NULL 
  AND failure_type IS NOT NULL
GROUP BY failure_type
ORDER BY mttr_minutes DESC;

-- MTTR trend by month
SELECT 
    YEAR(date) as year,
    MONTH(date) as month,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as mttr_minutes,
    CAST(AVG(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as mttr_hours
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;

-- Count of high risk equipment
SELECT 
    COUNT(DISTINCT equipment_id) as high_risk_equipment_count,
    COUNT(*) as high_risk_records
FROM predictive_maintenance
WHERE failure_risk_level = 'High';

-- High risk distribution by equipment type
SELECT 
    equipment_type,
    COUNT(DISTINCT equipment_id) as high_risk_equipment,
    COUNT(*) as high_risk_records,
    plant_area
FROM predictive_maintenance
WHERE failure_risk_level = 'High'
GROUP BY equipment_type, plant_area
ORDER BY high_risk_equipment DESC;

-- High risk equipment details
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    manufacturer,
    COUNT(*) as high_risk_occurrences,
    AVG(temperature_c) as avg_temp,
    AVG(vibration_mm_s) as avg_vibration,
    MAX(timestamp) as last_high_risk_timestamp
FROM predictive_maintenance
WHERE failure_risk_level = 'High'
GROUP BY equipment_id, equipment_type, plant_area, manufacturer
ORDER BY high_risk_occurrences DESC;

-- High risk trend over time
SELECT 
    YEAR(date) as year,
    MONTH(date) as month,
    COUNT(DISTINCT equipment_id) as high_risk_equipment,
    COUNT(*) as high_risk_records
FROM predictive_maintenance
WHERE failure_risk_level = 'High'
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;

                                        
										--SENSOR & HEALTH MONITORING KPIs--
-- Overall average temperature
SELECT 
    AVG(temperature_c) as avg_temperature,
    MIN(temperature_c) as min_temperature,
    MAX(temperature_c) as max_temperature,
    STDEV(temperature_c) as std_dev_temperature
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL;

-- Average temperature by equipment type
SELECT 
    equipment_type,
    AVG(temperature_c) as avg_temperature,
    MIN(temperature_c) as min_temperature,
    MAX(temperature_c) as max_temperature,
    STDEV(temperature_c) as std_dev_temperature,
    COUNT(*) as record_count
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL
GROUP BY equipment_type
ORDER BY avg_temperature DESC;

-- Average temperature by equipment
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    AVG(temperature_c) as avg_temperature,
    MAX(temperature_c) as max_temperature,
    AVG(CASE WHEN failure_flag = 1 THEN temperature_c END) as avg_temp_at_failure
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL
GROUP BY equipment_id, equipment_type, plant_area
ORDER BY avg_temperature DESC;

-- Temperature trend over time
SELECT 
    equipment_id,
    DATE(timestamp) as date,
    AVG(temperature_c) as avg_daily_temperature,
    MAX(temperature_c) as max_daily_temperature,
    MIN(temperature_c) as min_daily_temperature
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL
GROUP BY equipment_id, DATE(timestamp)
ORDER BY equipment_id, date;

-- Temperature comparison: normal vs failure
SELECT 
    equipment_type,
    AVG(CASE WHEN failure_flag = 0 THEN temperature_c END) as avg_temp_normal,
    AVG(CASE WHEN failure_flag = 1 THEN temperature_c END) as avg_temp_failure,
    AVG(CASE WHEN failure_flag = 1 THEN temperature_c END) - AVG(CASE WHEN failure_flag = 0 THEN temperature_c END) as temp_diff
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL
GROUP BY equipment_type
ORDER BY temp_diff DESC;

-- Overall average vibration
SELECT 
    AVG(vibration_mm_s) as avg_vibration,
    MIN(vibration_mm_s) as min_vibration,
    MAX(vibration_mm_s) as max_vibration,
    STDEV(vibration_mm_s) as std_dev_vibration
FROM predictive_maintenance
WHERE vibration_mm_s IS NOT NULL;

-- Average vibration by equipment type
SELECT 
    equipment_type,
    AVG(vibration_mm_s) as avg_vibration,
    MIN(vibration_mm_s) as min_vibration,
    MAX(vibration_mm_s) as max_vibration,
    STDEV(vibration_mm_s) as std_dev_vibration,
    CAST(STDEV(vibration_mm_s) / NULLIF(AVG(vibration_mm_s), 0) * 100 AS DECIMAL(5,2)) as coefficient_variation
FROM predictive_maintenance
WHERE vibration_mm_s IS NOT NULL
GROUP BY equipment_type
ORDER BY avg_vibration DESC;

-- Average vibration by equipment
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    manufacturer,
    AVG(vibration_mm_s) as avg_vibration,
    MAX(vibration_mm_s) as max_vibration,
    AVG(CASE WHEN failure_flag = 1 THEN vibration_mm_s END) as avg_vib_at_failure
FROM predictive_maintenance
WHERE vibration_mm_s IS NOT NULL
GROUP BY equipment_id, equipment_type, plant_area, manufacturer
ORDER BY avg_vibration DESC;

-- Vibration comparison: normal vs failure
SELECT 
    equipment_type,
    AVG(CASE WHEN failure_flag = 0 THEN vibration_mm_s END) as avg_vib_normal,
    AVG(CASE WHEN failure_flag = 1 THEN vibration_mm_s END) as avg_vib_failure,
    CAST((AVG(CASE WHEN failure_flag = 1 THEN vibration_mm_s END) - AVG(CASE WHEN failure_flag = 0 THEN vibration_mm_s END)) * 100.0 / 
         NULLIF(AVG(CASE WHEN failure_flag = 0 THEN vibration_mm_s END), 0) AS DECIMAL(5,2)) as vib_increase_pct
FROM predictive_maintenance
WHERE vibration_mm_s IS NOT NULL
GROUP BY equipment_type
ORDER BY vib_increase_pct DESC;

-- High vibration alerts (above threshold)
WITH vib_threshold AS (
    SELECT 
        equipment_type,
        AVG(vibration_mm_s) + 2 * STDEV(vibration_mm_s) as upper_threshold
    FROM predictive_maintenance
    WHERE vibration_mm_s IS NOT NULL
    GROUP BY equipment_type
)
SELECT 
    p.equipment_id,
    p.equipment_type,
    p.timestamp,
    p.vibration_mm_s,
    v.upper_threshold,
    p.failure_flag
FROM predictive_maintenance p
JOIN vib_threshold v ON p.equipment_type = v.equipment_type
WHERE p.vibration_mm_s > v.upper_threshold
ORDER BY p.vibration_mm_s DESC;

-- Health Index calculation (composite score based on multiple factors)
-- Health Index = 100 - (Temperature_Score + Vibration_Score + Efficiency_Score + Risk_Score) / 4
-- Lower values = better health

WITH normalized_metrics AS (
    SELECT 
        equipment_id,
        equipment_type,
        timestamp,
        -- Normalize temperature (0-100 scale, higher temp = higher score = worse)
        CASE 
            WHEN temperature_c <= 50 THEN 0
            WHEN temperature_c >= 100 THEN 100
            ELSE (temperature_c - 50) * 2
        END as temp_score,
        -- Normalize vibration (0-100 scale)
        CASE 
            WHEN vibration_mm_s <= 2 THEN 0
            WHEN vibration_mm_s >= 20 THEN 100
            ELSE (vibration_mm_s - 2) * 5.56
        END as vib_score,
        -- Efficiency score (inverse - low efficiency = high score = worse)
        100 - COALESCE(efficiency_percent, 80) as eff_score,
        -- Risk level score
        CASE failure_risk_level
            WHEN 'Low' THEN 0
            WHEN 'Medium' THEN 50
            WHEN 'High' THEN 100
            ELSE 25
        END as risk_score,
        failure_flag
    FROM predictive_maintenance
    WHERE temperature_c IS NOT NULL 
      AND vibration_mm_s IS NOT NULL
)
SELECT 
    equipment_id,
    equipment_type,
    AVG(temp_score) as avg_temp_score,
    AVG(vib_score) as avg_vib_score,
    AVG(eff_score) as avg_eff_score,
    AVG(risk_score) as avg_risk_score,
    CAST(100 - (AVG(temp_score) + AVG(vib_score) + AVG(eff_score) + AVG(risk_score)) / 4 AS DECIMAL(5,2)) as health_index,
    CASE 
        WHEN 100 - (AVG(temp_score) + AVG(vib_score) + AVG(eff_score) + AVG(risk_score)) / 4 >= 80 THEN 'Excellent'
        WHEN 100 - (AVG(temp_score) + AVG(vib_score) + AVG(eff_score) + AVG(risk_score)) / 4 >= 60 THEN 'Good'
        WHEN 100 - (AVG(temp_score) + AVG(vib_score) + AVG(eff_score) + AVG(risk_score)) / 4 >= 40 THEN 'Fair'
        WHEN 100 - (AVG(temp_score) + AVG(vib_score) + AVG(eff_score) + AVG(risk_score)) / 4 >= 20 THEN 'Poor'
        ELSE 'Critical'
    END as health_status,
    SUM(failure_flag) as failure_count
FROM normalized_metrics
GROUP BY equipment_id, equipment_type
ORDER BY health_index DESC;

-- Simplified Health Index by equipment type
SELECT 
    equipment_type,
    COUNT(DISTINCT equipment_id) as equipment_count,
    AVG(efficiency_percent) as avg_efficiency,
    AVG(temperature_c) as avg_temp,
    AVG(vibration_mm_s) as avg_vibration,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate,
    -- Simple health score
    CAST(AVG(efficiency_percent) - 
         (AVG(temperature_c) / 2) - 
         (AVG(vibration_mm_s) * 2) AS DECIMAL(5,2)) as health_index
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL 
  AND vibration_mm_s IS NOT NULL
  AND efficiency_percent IS NOT NULL
GROUP BY equipment_type
ORDER BY health_index DESC;

                                       --FAILURE PREDICTION & RISK KPIs--

-- Failure probability based on historical patterns
WITH equipment_stats AS (
    SELECT 
        equipment_id,
        COUNT(*) as total_records,
        SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failure_count,
        AVG(temperature_c) as avg_temp,
        AVG(vibration_mm_s) as avg_vib,
        AVG(efficiency_percent) as avg_efficiency
    FROM predictive_maintenance
    GROUP BY equipment_id
)
SELECT 
    equipment_id,
    total_records,
    failure_count,
    CAST(failure_count * 100.0 / total_records AS DECIMAL(5,2)) as historical_failure_probability_pct,
    avg_temp,
    avg_vib,
    avg_efficiency,
    CASE 
        WHEN failure_count * 100.0 / total_records >= 10 THEN 'Very High'
        WHEN failure_count * 100.0 / total_records >= 5 THEN 'High'
        WHEN failure_count * 100.0 / total_records >= 2 THEN 'Medium'
        ELSE 'Low'
    END as predicted_risk_category
FROM equipment_stats
ORDER BY historical_failure_probability_pct DESC;

-- Failure probability by conditions
SELECT 
    equipment_type,
    CASE 
        WHEN temperature_c >= 80 THEN 'High Temp'
        WHEN temperature_c >= 60 THEN 'Medium Temp'
        ELSE 'Normal Temp'
    END as temp_category,
    CASE 
        WHEN vibration_mm_s >= 10 THEN 'High Vibration'
        WHEN vibration_mm_s >= 5 THEN 'Medium Vibration'
        ELSE 'Normal Vibration'
    END as vib_category,
    COUNT(*) as total_records,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as failures,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_probability_pct
FROM predictive_maintenance
WHERE temperature_c IS NOT NULL AND vibration_mm_s IS NOT NULL
GROUP BY 
    equipment_type,
    CASE 
        WHEN temperature_c >= 80 THEN 'High Temp'
        WHEN temperature_c >= 60 THEN 'Medium Temp'
        ELSE 'Normal Temp'
    END,
    CASE 
        WHEN vibration_mm_s >= 10 THEN 'High Vibration'
        WHEN vibration_mm_s >= 5 THEN 'Medium Vibration'
        ELSE 'Normal Vibration'
    END
ORDER BY failure_probability_pct DESC;

-- Current failure probability based on latest readings
WITH latest_readings AS (
    SELECT 
        equipment_id,
        equipment_type,
        temperature_c,
        vibration_mm_s,
        efficiency_percent,
        failure_risk_level,
        ROW_NUMBER() OVER (PARTITION BY equipment_id ORDER BY timestamp DESC) as rn
    FROM predictive_maintenance
),
historical_failure_rate AS (
    SELECT 
        equipment_type,
        CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as baseline_failure_rate
    FROM predictive_maintenance
    GROUP BY equipment_type
)
SELECT 
    l.equipment_id,
    l.equipment_type,
    l.temperature_c as current_temp,
    l.vibration_mm_s as current_vibration,
    l.efficiency_percent as current_efficiency,
    l.failure_risk_level as current_risk_level,
    h.baseline_failure_rate,
    CASE 
        WHEN l.failure_risk_level = 'High' THEN h.baseline_failure_rate * 3
        WHEN l.failure_risk_level = 'Medium' THEN h.baseline_failure_rate * 1.5
        ELSE h.baseline_failure_rate * 0.5
    END as adjusted_failure_probability_pct
FROM latest_readings l
JOIN historical_failure_rate h ON l.equipment_type = h.equipment_type
WHERE l.rn = 1
ORDER BY adjusted_failure_probability_pct DESC;

-- Overall risk level distribution
SELECT 
    failure_risk_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT equipment_id) as equipment_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) as percentage
FROM predictive_maintenance
WHERE failure_risk_level IS NOT NULL
GROUP BY failure_risk_level
ORDER BY 
    CASE failure_risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

-- Risk level distribution by equipment type
SELECT 
    equipment_type,
    failure_risk_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT equipment_id) as equipment_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY equipment_type) AS DECIMAL(5,2)) as percentage_within_type
FROM predictive_maintenance
WHERE failure_risk_level IS NOT NULL
GROUP BY equipment_type, failure_risk_level
ORDER BY equipment_type, 
    CASE failure_risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

-- Risk level distribution by plant area
SELECT 
    plant_area,
    failure_risk_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT equipment_id) as equipment_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY plant_area) AS DECIMAL(5,2)) as percentage_within_area
FROM predictive_maintenance
WHERE failure_risk_level IS NOT NULL
GROUP BY plant_area, failure_risk_level
ORDER BY plant_area, 
    CASE failure_risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

-- Risk level trend over time
SELECT 
    YEAR(date) as year,
    MONTH(date) as month,
    failure_risk_level,
    COUNT(DISTINCT equipment_id) as equipment_count,
    COUNT(*) as record_count
FROM predictive_maintenance
WHERE failure_risk_level IS NOT NULL
GROUP BY YEAR(date), MONTH(date), failure_risk_level
ORDER BY year, month, 
    CASE failure_risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

	                                   --DOWNTIME KPIs--

-- Overall total downtime
SELECT 
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    CAST(SUM(downtime_minutes) / 1440.0 AS DECIMAL(10,2)) as total_downtime_days,
    COUNT(*) as total_failure_events,
    AVG(downtime_minutes) as avg_downtime_per_failure
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL;

-- Total downtime by equipment type
SELECT 
    equipment_type,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as avg_downtime_per_failure,
    MIN(downtime_minutes) as min_downtime,
    MAX(downtime_minutes) as max_downtime
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_type
ORDER BY total_downtime_minutes DESC;

-- Total downtime by plant area
SELECT 
    plant_area,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(DISTINCT equipment_id) as affected_equipment,
    COUNT(*) as failure_count
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY plant_area
ORDER BY total_downtime_minutes DESC;

-- Monthly downtime trend
SELECT 
    YEAR(date) as year,
    MONTH(date) as month,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as avg_downtime
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;

-- Downtime by failure type
SELECT 
    failure_type,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(*) as occurrence_count,
    AVG(downtime_minutes) as avg_downtime_per_occurrence,
    CAST(SUM(downtime_minutes) * 100.0 / 
         (SELECT SUM(downtime_minutes) FROM predictive_maintenance WHERE failure_flag = 1) 
         AS DECIMAL(5,2)) as percentage_of_total_downtime
FROM predictive_maintenance
WHERE failure_flag = 1 
  AND downtime_minutes IS NOT NULL 
  AND failure_type IS NOT NULL
GROUP BY failure_type
ORDER BY total_downtime_minutes DESC;

-- Downtime summary by equipment
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    manufacturer,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as avg_downtime_per_failure,
    MIN(downtime_minutes) as min_downtime,
    MAX(downtime_minutes) as max_downtime,
    MAX(timestamp) as last_failure_timestamp
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_id, equipment_type, plant_area, manufacturer
ORDER BY total_downtime_minutes DESC;

-- Top 10 equipment by downtime
SELECT TOP 10
    equipment_id,
    equipment_type,
    plant_area,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(SUM(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as avg_downtime_per_failure
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_id, equipment_type, plant_area
ORDER BY total_downtime_minutes DESC;

-- Equipment with highest average downtime per failure
SELECT 
    equipment_id,
    equipment_type,
    plant_area,
    COUNT(*) as failure_count,
    AVG(downtime_minutes) as avg_downtime_per_failure,
    SUM(downtime_minutes) as total_downtime_minutes,
    CAST(AVG(downtime_minutes) / 60.0 AS DECIMAL(10,2)) as avg_downtime_hours
FROM predictive_maintenance
WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
GROUP BY equipment_id, equipment_type, plant_area
HAVING COUNT(*) >= 3  -- At least 3 failures for statistical relevance
ORDER BY avg_downtime_per_failure DESC;

-- Equipment downtime comparison with benchmarks
WITH equipment_downtime AS (
    SELECT 
        equipment_id,
        equipment_type,
        SUM(downtime_minutes) as total_downtime,
        AVG(downtime_minutes) as avg_downtime
    FROM predictive_maintenance
    WHERE failure_flag = 1 AND downtime_minutes IS NOT NULL
    GROUP BY equipment_id, equipment_type
),
type_benchmarks AS (
    SELECT 
        equipment_type,
        AVG(total_downtime) as type_avg_downtime,
        AVG(avg_downtime) as type_avg_per_failure
    FROM equipment_downtime
    GROUP BY equipment_type
)
SELECT 
    e.equipment_id,
    e.equipment_type,
    e.total_downtime as equipment_total_downtime,
    e.avg_downtime as equipment_avg_downtime,
    b.type_avg_downtime as type_benchmark_total,
    b.type_avg_per_failure as type_benchmark_avg,
    CAST((e.total_downtime - b.type_avg_downtime) * 100.0 / b.type_avg_downtime AS DECIMAL(5,2)) as variance_from_benchmark_pct,
    CASE 
        WHEN e.total_downtime > b.type_avg_downtime * 1.5 THEN 'Critical'
        WHEN e.total_downtime > b.type_avg_downtime * 1.2 THEN 'Above Average'
        WHEN e.total_downtime < b.type_avg_downtime * 0.8 THEN 'Below Average'
        ELSE 'Average'
    END as performance_category
FROM equipment_downtime e
JOIN type_benchmarks b ON e.equipment_type = b.equipment_type
ORDER BY variance_from_benchmark_pct DESC;


                                ---COMPREHENSIVE DASHBOARD QUERY---

                         -- Executive KPI Dashboard - All Key Metrics
SELECT 
    'Overall Performance' as metric_category,
    -- Reliability Metrics
    COUNT(DISTINCT equipment_id) as total_equipment,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct,
    CAST(SUM(operating_hours) / NULLIF(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END), 0) AS DECIMAL(10,2)) as mtbf_hours,
    CAST(AVG(CASE WHEN failure_flag = 1 THEN downtime_minutes END) / 60.0 AS DECIMAL(10,2)) as mttr_hours,
    
    -- Risk Metrics
    COUNT(DISTINCT CASE WHEN failure_risk_level = 'High' THEN equipment_id END) as high_risk_equipment,
    CAST(COUNT(CASE WHEN failure_risk_level = 'High' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as high_risk_pct,
    
    -- Sensor Metrics
    CAST(AVG(temperature_c) AS DECIMAL(5,2)) as avg_temperature,
    CAST(AVG(vibration_mm_s) AS DECIMAL(5,2)) as avg_vibration,
    CAST(AVG(efficiency_percent) AS DECIMAL(5,2)) as avg_efficiency,
    
    -- Downtime Metrics
    CAST(SUM(CASE WHEN failure_flag = 1 THEN downtime_minutes ELSE 0 END) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours,
    SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) as total_failures,
    
    -- Cost Impact (if cost data available)
    CAST(SUM(energy_consumption_kwh) AS DECIMAL(10,2)) as total_energy_consumption
FROM predictive_maintenance;

-- Equipment Type Summary
SELECT 
    equipment_type,
    COUNT(DISTINCT equipment_id) as equipment_count,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as failure_rate_pct,
    CAST(AVG(CASE WHEN failure_flag = 1 THEN downtime_minutes END) AS DECIMAL(10,2)) as avg_mttr_minutes,
    COUNT(DISTINCT CASE WHEN failure_risk_level = 'High' THEN equipment_id END) as high_risk_count,
    CAST(AVG(temperature_c) AS DECIMAL(5,2)) as avg_temp,
    CAST(AVG(vibration_mm_s) AS DECIMAL(5,2)) as avg_vibration,
    CAST(SUM(CASE WHEN failure_flag = 1 THEN downtime_minutes ELSE 0 END) / 60.0 AS DECIMAL(10,2)) as total_downtime_hours
FROM predictive_maintenance
WHERE equipment_type IS NOT NULL
GROUP BY equipment_type
ORDER BY failure_rate_pct DESC;