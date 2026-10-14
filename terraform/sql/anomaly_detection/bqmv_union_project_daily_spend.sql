-- Step 1 & 2: UNION the project daily spend tables from each billing account dataset
WITH
project_daily_spend AS (
    -- Join Set 1: billing_account_1
    SELECT *
    FROM `${billing_account_1_prj_daily_spend_table_name}` AS base

    -- Join Set 2: billing_account_2
    UNION ALL
    SELECT *
    FROM `${billing_account_2_prj_daily_spend_table_name}` AS base

    -- Join Set 3: billing_account_3
    UNION ALL
    SELECT *
    FROM `${billing_account_3_prj_daily_spend_table_name}` AS base

    -- Join Set 4: billing_account_4
    UNION ALL
    SELECT *
    FROM `${billing_account_4_prj_daily_spend_table_name}` AS base
)

-- Final SELECT statement for the Materialized View
SELECT
    -- Select all columns from the pre-joined and unioned data
    project_daily_spend.*,

    -- 1. Billing Account Name (Replace placeholder IDs and names with your organization's Cloud Billing Accounts)
    CASE
        WHEN project_daily_spend.billing_account_id = "000000-000000-000001" THEN "billing_account_1"
        WHEN project_daily_spend.billing_account_id = "000000-000000-000002" THEN "billing_account_2"
        WHEN project_daily_spend.billing_account_id = "000000-000000-000003" THEN "billing_account_3"
        WHEN project_daily_spend.billing_account_id = "000000-000000-000004" THEN "billing_account_4"
        ELSE NULL
    END AS billing_account_name,

    -- 2. Dynamic Fiscal Year, Period, and Week Calculations
    -- Uses native EXTRACT() so any historical or future year is supported automatically.
    -- Tip: If your fiscal year starts in a month other than January (e.g., October = +3 months),
    -- wrap DATE(project_daily_spend.usage_start_date) with DATE_ADD(DATE(project_daily_spend.usage_start_date), INTERVAL 3 MONTH).
    EXTRACT(YEAR FROM DATE(project_daily_spend.usage_start_date)) AS fiscal_year,
    EXTRACT(MONTH FROM DATE(project_daily_spend.usage_start_date)) AS fiscal_period,
    EXTRACT(ISOWEEK FROM DATE(project_daily_spend.usage_start_date)) AS fiscal_week
FROM
    project_daily_spend
