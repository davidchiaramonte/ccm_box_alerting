WITH
anomaly_data_1 AS (
    SELECT
    date(c.usage_start_date) AS usage_start_date,
    c.project_name AS project_name,
    c.project_id AS project_id,
    c.total_net_cost AS total_net_cost,
    coalesce(c.is_anomaly, h.is_anomaly) AS is_anomaly,
    coalesce(c.lower_bound, h.lower_bound) AS lower_bound,
    coalesce(c.upper_bound, h.upper_bound) AS upper_bound,
    coalesce(c.anomaly_probability, h.anomaly_probability) AS anomaly_probability
    FROM
    (
        --Forecasted input_data (returns all rows but only anomaly details for forecasting period)
        SELECT
        *
        FROM
        ML.DETECT_ANOMALIES(
            MODEL `${project_net_cost_forecast}`,
            STRUCT(CAST(0.99 AS NUMERIC) AS anomaly_prob_threshold),
            (
            SELECT
                *
            FROM
                `${union_project_daily_spend}`
            )
        )
    ) c
    LEFT JOIN (
        --Modeled input_data (returns only rows and anomaly details for historical data used to create model)
        SELECT
        *
        FROM
        ML.DETECT_ANOMALIES(
            MODEL `${project_net_cost_forecast}`,
            STRUCT(CAST(0.99 AS NUMERIC) AS anomaly_prob_threshold)
        )
    ) h ON c.project_id = h.project_id
    AND c.usage_start_date = h.usage_start_date
),
anomaly_data_2 AS (
    SELECT
    *,
    CASE
        WHEN total_net_cost > upper_bound THEN total_net_cost - upper_bound
        ELSE NULL
    END AS delta_above_upper_bound,
    CASE
        WHEN total_net_cost < lower_bound THEN total_net_cost - lower_bound
        ELSE NULL
    END AS delta_below_lower_bound,
    CASE
        WHEN total_net_cost > upper_bound THEN (SAFE_DIVIDE(total_net_cost - upper_bound, upper_bound))
        ELSE NULL
    END AS percent_above_upper_bound,
    CASE
        WHEN total_net_cost < lower_bound THEN (SAFE_DIVIDE(total_net_cost - lower_bound, lower_bound))
        ELSE NULL
    END AS percent_below_lower_bound
    FROM
    anomaly_data_1
),
anomaly_data_3 AS (
    SELECT
    *,
    CASE
        WHEN is_anomaly THEN coalesce(delta_above_upper_bound, delta_below_lower_bound)
    END AS absolute_distance_from_threshold,
    abs(
        CASE
        WHEN is_anomaly THEN coalesce(percent_above_upper_bound, percent_below_lower_bound)
        END
    ) AS absolute_percent_from_threshold
    FROM
    anomaly_data_2
)
SELECT
anomaly_data_3.*,
-- Add the anomaly_direction field here
CASE
    WHEN is_anomaly
    AND total_net_cost > upper_bound THEN 'Above'
    WHEN is_anomaly
    AND total_net_cost < lower_bound THEN 'Below'
    ELSE NULL
END AS anomaly_direction,
t AS alert
FROM
anomaly_data_3
LEFT JOIN `${cost_anomaly_alert_log}` AS t
ON anomaly_data_3.project_id = t.project_id AND anomaly_data_3.usage_start_date = t.usage_start_date
      --Note that if there are duplicate project_id records in log that will result in duplicating the anomaly