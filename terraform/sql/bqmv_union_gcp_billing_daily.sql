-- Step 1 & 2: UNION the daily left-joined billing tables from each billing account dataset
WITH
left_joined_data AS (
    -- Join Set 1: billing_account_1
    SELECT *
    FROM `${billing_account_1_left_joined}` AS base

    -- Join Set 2: billing_account_2
    UNION ALL
    SELECT *
    FROM `${billing_account_2_left_joined}` AS base

    -- Join Set 3: billing_account_3
    UNION ALL
    SELECT *
    FROM `${billing_account_3_left_joined}` AS base

    -- Join Set 4: billing_account_4
    UNION ALL
    SELECT *
    FROM `${billing_account_4_left_joined}` AS base
)

-- Final SELECT statement for the Materialized View
SELECT
    -- Select all columns from the pre-joined and unioned data
    billing.*,

    -- 1. Billing Account Name (Replace placeholder IDs and names with your organization's Cloud Billing Accounts)
    CASE
        WHEN billing.billing_account_id = "000000-000000-000001" THEN "billing_account_1"
        WHEN billing.billing_account_id = "000000-000000-000002" THEN "billing_account_2"
        WHEN billing.billing_account_id = "000000-000000-000003" THEN "billing_account_3"
        WHEN billing.billing_account_id = "000000-000000-000004" THEN "billing_account_4"
        ELSE NULL
    END AS billing_account_name,

    -- 2. Dynamic Fiscal Year, Period, and Week Calculations
    -- Uses native EXTRACT() so any historical or future year is supported automatically.
    -- Tip: If your fiscal year starts in a month other than January (e.g., October = +3 months),
    -- wrap DATE(billing.usage_start_date) with DATE_ADD(DATE(billing.usage_start_date), INTERVAL 3 MONTH).
    EXTRACT(YEAR FROM DATE(billing.usage_start_date)) AS fiscal_year,
    EXTRACT(MONTH FROM DATE(billing.usage_start_date)) AS fiscal_period,
    EXTRACT(ISOWEEK FROM DATE(billing.usage_start_date)) AS fiscal_week
FROM
    left_joined_data AS billing
