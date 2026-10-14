WITH
-- ============================================================================
-- Step 1: Get Top 5 SKUs from the MOST LIKELY service
-- ============================================================================
top_skus AS (
SELECT
    sku_description
FROM
    `${union_gcp_billing_daily}`
WHERE
    COALESCE(project_id, 'No Project ID') = p_project_id
    AND DATE(usage_start_date) = p_target_date
    AND COALESCE(service_description, 'No Service Description') = p_service_description
GROUP BY
    1
ORDER BY
    COALESCE(SUM(total_fcud_legacy), 0) + COALESCE(SUM(total_cost), 0) DESC
LIMIT
    5
),
-- Step 2: Get cost history for just those top 5 SKUs
daily_sku_costs AS (
SELECT
    DATE(usage_start_date) AS usage_date,
    sku_description,
    COALESCE(SUM(total_fcud_legacy), 0) + COALESCE(SUM(total_cost), 0) AS total_net_cost
FROM
    `${union_gcp_billing_daily}`
WHERE
    COALESCE(project_id, 'No Project ID') = p_project_id
    AND DATE(usage_start_date) IN (
    p_target_date,
    DATE_SUB(p_target_date, INTERVAL 1 DAY),
    DATE_SUB(p_target_date, INTERVAL 2 DAY),
    DATE_SUB(p_target_date, INTERVAL 3 DAY)
    )
    AND COALESCE(service_description, 'No Service Description') = p_service_description
    AND sku_description IN (
    SELECT
        sku_description
    FROM
        top_skus
    )
GROUP BY
    1,
    2
),
-- Step 3: Format the SKU data into a single string
sku_cost_list_string AS (
SELECT
    STRING_AGG(
    CONCAT(
        sku_description,
        ' (',
        FORMAT_DATE('%Y-%m-%d', usage_date),
        ': $',
        CAST(total_net_cost AS STRING),
        ')'
    ),
    ', '
    ORDER BY
        sku_description,
        usage_date
    ) AS service_sku_netcost_list
FROM
    daily_sku_costs
),
-- ============================================================================
-- Step 4: Construct the final prompt
-- ============================================================================
prompt_data AS (
SELECT
    CONCAT(
    'On ',
    CAST(p_target_date AS STRING),
    ' there was a cost anomaly of $',
    CAST(p_distance_from_threshold AS STRING),
    ' over expected costs in the Google Cloud Platform project named ',
    p_project_name,
    '.',
    ' The ',
    p_service_description,
    ' service had the greatest percent increase of any service on that day (when compared to multiple days in the past), and therefore is the most likely service with the anomaly.',
    ' For additional project-wide context, here are the top 5 services by percentage increase (comparing target date to the 3-day average), along with their 4-day cost history: ',
    p_top_service_increase_list,
    '.',
    ' Now, focusing on the most likely service (',
    p_service_description,
    '), here is a list of its top 5 skus by net cost on that day and their net costs from the 3 previous days: ',
    (
        SELECT
        service_sku_netcost_list
        FROM
        sku_cost_list_string
    ),
    '. Start with an explanation of which sku likely caused it and why it is most likely.',
    ' Given the services running on that project, provide a concise explanation of the anomaly,',
    ' along with a bulleted list of up to three tips on what could be done to prevent further unwanted overspending.',
    ' Do not suggest budget alerts as a possible solution to the cost anomaly.',
    ' Do not suggest purchasing a committed use discount as a new solution to the cost anomaly.',
    ' Do not suggest purchasing BigQuery Slots as a possible solution to the cost anomaly as a possible solution to the cost anomaly.',
    ' Do not suggest looking at cloud costs in the google cloud console as a new solution to the cost anomaly.',
    ' Do not suggest creating an Object Lifecycle Management policy as a possible solution to the cost anomaly.',
    ' Keep the response under 150 words.',
    ' Follow this template:',
    ' A description of the anomaly.',
    ' The likely causes of the anomaly.',
    ' Reason why that is the likely cause.',
    ' Potential corrective actions include: ',
    '<br>• Corrective action 1',
    '<br>• Corrective action 2',
    '<br>• Corrective action 3'
    ) AS prompt
)
-- ============================================================================
-- Step 5: Return the generated prompt
-- ============================================================================
SELECT
    prompt
FROM
    prompt_data