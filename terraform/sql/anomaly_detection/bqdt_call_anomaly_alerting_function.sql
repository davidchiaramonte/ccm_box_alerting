-- This query is now only responsible for finding unalerted anomalies
-- from the 'vw_unalerted_anomalies' view and sending the base data
-- to the Cloud Run endpoint.
-- The Cloud Run endpoint will handle all enrichment.

BEGIN
WITH
  -- 1. Get all unalerted anomalies. This view reads from the ML model
  -- output and does NOT have a partition-enforcement issue.
  unalerted_data AS (
    SELECT
      a.*, b.owner_email as owner
      , b.department_name
    FROM
      `${vw_unalerted_anomalies}` a
      left join `${project_owner_mapping}` b on a.project_id = b.project_id
      --Note that if there are duplicate project_id records that will result in handling the alert twice
  ),
  -- 2. Construct the final JSON payload for the Cloud Run function
  final_payload AS (
    SELECT
      TO_JSON(
        STRUCT(
          a.project_id,
          a.project_name,
          a.anomaly_date,
          a.absolute_distance_from_threshold,
          a.absolute_percent_from_threshold,
          a.total_net_cost,
          a.anomaly_direction,
          a.forecast_upper_bound,
          a.forecast_lower_bound,
          a.owner,
          a.department_name
        )
      ) AS json_payload
    FROM
      unalerted_data AS a
    ORDER BY
    -- [CRITICAL] Force chronological processing (Oldest -> Newest) when using limit in dev. Shouldn't matter if pulling all in normal production since the cloud function also sorts the anomalies
    project_id ASC,
    anomaly_date ASC
    -- limit 2 --for testing, to not "use up" all test samples. Can also truncate the alert log table if need to start over
  )
-- 3. Call the remote function. It will now do the heavy lifting
-- of calling the other BQ functions, which solves the partition error.
SELECT
  `${sp_anomaly_alert_function}`(json_payload) AS function_response,
  final_payload.*
FROM
  final_payload
  ;
END;
