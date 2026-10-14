CREATE OR REPLACE MODEL `${project_net_cost_forecast}`
OPTIONS(  MODEL_TYPE = 'ARIMA_PLUS'
,  TIME_SERIES_TIMESTAMP_COL = 'usage_start_date'
,  TIME_SERIES_DATA_COL = 'total_net_cost'
,  TIME_SERIES_ID_COL = ['project_id']
,  HORIZON = 90 --horizon -- TODO: Make forecast horizon customizable
--    ,  HOLIDAY_REGION =  'US' -- Acceptable values are 'GLOBAL' or ['US', 'GB']. If enabled, update Step 4
,  AUTO_ARIMA = TRUE
-- ,  FORECAST_LIMIT_LOWER_BOUND = 0 --Total net costs will never be negative - but cannot use this since this prevents model from running "ml.detect_anomalies" function
)
AS (SELECT usage_start_date,project_id,total_net_cost FROM `${vw_project_input_data_net_cost}`);

UPDATE `${anomaly_detection_bqml_model_info}`
SET is_latest_model_version = FALSE
WHERE model_name = 'project_net_cost_forecast'
AND is_latest_model_version = TRUE
;

-- Remove all existing rows of this table to contain info about current run
TRUNCATE TABLE `${project_create_model_net_cost}`;

-- Insert the new desired row, so info on current run can be used in several places below
INSERT `${project_create_model_net_cost}`
(model_name, model_type, date_created, horizon, holiday_region, bigquery_dataset)
SELECT
'project_net_cost_forecast' AS model_name,
'ARIMA_PLUS' AS model_type,
CURRENT_TIMESTAMP() AS date_created,
90 AS horizon,
'NA' AS holiday_region,
'${dataset_id}' AS bigquery_dataset;

INSERT `${anomaly_detection_bqml_model_info}`
WITH d AS (SELECT  MIN(usage_start_date) as min_date
                , MAX(usage_start_date) as max_date
        FROM `${vw_project_input_data_net_cost}`)
    ,t AS (SELECT duration_ms
        FROM ML.TRAINING_INFO(MODEL `${project_net_cost_forecast}`))
    ,f AS (SELECT ARRAY_AGG(STRUCT(input,min,max,median,stddev,category_count,null_count)) AS feature_info
        FROM ML.FEATURE_INFO(MODEL `${project_net_cost_forecast}`))

SELECT log.*
,d.min_date
,d.max_date
,t.duration_ms
,f.feature_info
,TRUE AS is_latest_model_version
FROM `${project_create_model_net_cost}` AS log
CROSS JOIN d
CROSS JOIN t
CROSS JOIN f
;

UPDATE `${dataset_id}.arima_evaluate_project_net_cost_forecast`
SET is_latest_model_version = FALSE
WHERE is_latest_model_version = TRUE
;

INSERT `${dataset_id}.arima_evaluate_project_net_cost_forecast`
WITH c AS (SELECT *
        FROM ML.ARIMA_COEFFICIENTS(MODEL `${project_net_cost_forecast}`))
    ,e AS (SELECT *
        FROM ML.ARIMA_EVALUATE(MODEL `${project_net_cost_forecast}`))

SELECT m.model_name
,m.date_created
,c.project_id
,c.ar_coefficients
,c.ma_coefficients
,c.intercept_or_drift
,e.* EXCEPT(project_id)
, TRUE AS is_latest_model_version
FROM c
JOIN e on c.project_id = e.project_id
CROSS JOIN `${project_create_model_net_cost}` m
;

select * FROM `${project_create_model_net_cost}`;