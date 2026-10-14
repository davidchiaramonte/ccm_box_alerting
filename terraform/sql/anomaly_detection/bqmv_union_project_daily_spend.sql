-- Step 1 & 2: Join each base table with its labels table, then UNION them all together
WITH
project_daily_spend AS (
    -- Join Set 1: costcoit
    SELECT *
    FROM `${costcoit_prj_daily_spend_table_name}` AS base
    
    -- Join Set 2: costco2
    UNION ALL
    SELECT *
    FROM `${costco2_prj_daily_spend_table_name}` AS base

    -- Join Set 3: nxt
    UNION ALL
    SELECT *
    FROM `${nxt_prj_daily_spend_table_name}` AS base

    -- Join Set 4: world billing
    UNION ALL
    SELECT *
    FROM `${world_prj_daily_spend_table_name}` AS base
)

-- Final SELECT statement for the Materialized View
SELECT
-- Select all columns from the pre-joined and unioned data
project_daily_spend.*,

-- 1. Billing Account Name
CASE
    WHEN project_daily_spend.billing_account_id = "00D4E7-5D0B87-4C9F55" THEN "Costco-it.com"
    WHEN project_daily_spend.billing_account_id = "0137D4-78E48D-E4461F" THEN "Costco.com-2"
    WHEN project_daily_spend.billing_account_id = "01AC98-80549F-CA9823" THEN "International Ecommerce"
    WHEN project_daily_spend.billing_account_id = "014CA2-C0AFFC-1F5F26" THEN "nxt.costco.com"
    ELSE NULL
END AS billing_account_name,

-- 2. Fiscal Year Calculation 
CASE
    -- Confirmed Years (FY 2023 - 2026)
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN 2023 -- 53-WEEK CATCHUP YEAR
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN 2024
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN 2025
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN 2026

    -- Projected Years (FY 2027 - 2047) - Based on 6-year catchup cycle (53W years: 2029, 2035, 2041, 2047)
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN 2027
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN 2028
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN 2029 -- 53-WEEK CATCHUP YEAR
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN 2030
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN 2031
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN 2032
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN 2033
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN 2034
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN 2035 -- 53-WEEK CATCHUP YEAR
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN 2036
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN 2037
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN 2038
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN 2039
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN 2040
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN 2041 -- 53-WEEK CATCHUP YEAR
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN 2042
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN 2043
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN 2044
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN 2045
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN 2046
    WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN 2047 -- 53-WEEK CATCHUP YEAR
    ELSE NULL
END AS fiscal_year,

-- 3. Fiscal Period Calculation 
CASE
    -- This inner section defines the start date of the current Fiscal Year (FY Start)
    WHEN DIV(
    DATE_DIFF(
        DATE(project_daily_spend.usage_start_date),
        DATE(
        -- INNER CASE: Defines the Fiscal Year Start Date to anchor the calculation
        CASE
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN '2022-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN '2023-09-04'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN '2024-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN '2025-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN '2026-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN '2027-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN '2028-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN '2029-09-03'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN '2030-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN '2031-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN '2032-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN '2033-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN '2034-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN '2035-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN '2036-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN '2037-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN '2038-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN '2039-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN '2040-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN '2041-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN '2042-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN '2043-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN '2044-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN '2045-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN '2046-08-27'
            ELSE NULL
        END
        ),
        DAY
    ),
    28
    ) + 1 > 13 THEN 13
    
    -- ELSE: Standard period calculation for P1-P12
    ELSE DIV(
    DATE_DIFF(
        DATE(project_daily_spend.usage_start_date),
        DATE(
        CASE
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN '2022-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN '2023-09-04'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN '2024-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN '2025-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN '2026-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN '2027-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN '2028-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN '2029-09-03'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN '2030-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN '2031-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN '2032-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN '2033-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN '2034-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN '2035-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN '2036-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN '2037-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN '2038-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN '2039-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN '2040-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN '2041-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN '2042-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN '2043-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN '2044-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN '2045-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN '2046-08-27'
            ELSE NULL
        END
        ),
        DAY
    ),
    28
    ) + 1
END AS fiscal_period,

-- 4. Fiscal Week Calculation
CASE
    -- Check if the current period is Period 13 (Days 336 and above)
    WHEN DIV(
    DATE_DIFF(
        DATE(project_daily_spend.usage_start_date),
        DATE(
        -- Get FY Start Date
        CASE
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN '2022-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN '2023-09-04'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN '2024-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN '2025-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN '2026-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN '2027-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN '2028-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN '2029-09-03'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN '2030-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN '2031-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN '2032-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN '2033-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN '2034-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN '2035-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN '2036-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN '2037-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN '2038-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN '2039-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN '2040-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN '2041-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN '2042-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN '2043-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN '2044-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN '2045-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN '2046-08-27'
            ELSE NULL
        END
        ),
        DAY
    ),
    28
    ) + 1 > 12 THEN
    (
        -- Calculation for Week in Period 13 (W1 to W4 or W5)
        DIV(
        DATE_DIFF(
            DATE(project_daily_spend.usage_start_date),
            DATE(
            -- Start date of Period 13 (which is always 336 days after FY start)
            CASE
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN DATE_ADD(DATE '2022-08-29', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN DATE_ADD(DATE '2023-09-04', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN DATE_ADD(DATE '2024-09-02', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN DATE_ADD(DATE '2025-09-01', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN DATE_ADD(DATE '2026-08-31', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN DATE_ADD(DATE '2027-08-30', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN DATE_ADD(DATE '2028-08-28', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN DATE_ADD(DATE '2029-09-03', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN DATE_ADD(DATE '2030-09-02', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN DATE_ADD(DATE '2031-09-01', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN DATE_ADD(DATE '2032-08-30', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN DATE_ADD(DATE '2033-08-29', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN DATE_ADD(DATE '2034-08-28', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN DATE_ADD(DATE '2035-09-02', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN DATE_ADD(DATE '2036-09-01', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN DATE_ADD(DATE '2037-08-31', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN DATE_ADD(DATE '2038-08-30', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN DATE_ADD(DATE '2039-08-29', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN DATE_ADD(DATE '2040-08-28', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN DATE_ADD(DATE '2041-09-02', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN DATE_ADD(DATE '2042-09-01', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN DATE_ADD(DATE '2043-08-31', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN DATE_ADD(DATE '2044-08-29', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN DATE_ADD(DATE '2045-08-28', INTERVAL 336 DAY)
                WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN DATE_ADD(DATE '2046-08-27', INTERVAL 336 DAY)
                ELSE NULL
            END
            ),
            DAY
        ),
        7
        ) + 1
    )
    
    -- ELSE: Standard Week calculation for Periods 1 through 12 (W1-W4)
    ELSE MOD(
    DIV(
        DATE_DIFF(
        DATE(project_daily_spend.usage_start_date),
        DATE(
            -- Get FY Start Date
            CASE
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2022-08-29' AND '2023-09-03' THEN '2022-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2023-09-04' AND '2024-09-01' THEN '2023-09-04'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2024-09-02' AND '2025-08-31' THEN '2024-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2025-09-01' AND '2026-08-30' THEN '2025-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2026-08-31' AND '2027-08-29' THEN '2026-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2027-08-30' AND '2028-08-27' THEN '2027-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2028-08-28' AND '2029-09-02' THEN '2028-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2029-09-03' AND '2030-09-01' THEN '2029-09-03'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2030-09-02' AND '2031-08-31' THEN '2030-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2031-09-01' AND '2032-08-29' THEN '2031-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2032-08-30' AND '2033-08-28' THEN '2032-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2033-08-29' AND '2034-08-27' THEN '2033-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2034-08-28' AND '2035-09-01' THEN '2034-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2035-09-02' AND '2036-08-31' THEN '2035-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2036-09-01' AND '2037-08-30' THEN '2036-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2037-08-31' AND '2038-08-29' THEN '2037-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2038-08-30' AND '2039-08-28' THEN '2038-08-30'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2039-08-29' AND '2040-08-27' THEN '2039-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2040-08-28' AND '2041-09-01' THEN '2040-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2041-09-02' AND '2042-08-31' THEN '2041-09-02'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2042-09-01' AND '2043-08-30' THEN '2042-09-01'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2043-08-31' AND '2044-08-28' THEN '2043-08-31'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2044-08-29' AND '2045-08-27' THEN '2044-08-29'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2045-08-28' AND '2046-08-26' THEN '2045-08-28'
            WHEN DATE(project_daily_spend.usage_start_date) BETWEEN '2046-08-27' AND '2047-08-31' THEN '2046-08-27'
            ELSE NULL
            END
        ),
        DAY
        ),
        7
    ),
    4
    ) + 1
END AS fiscal_week
FROM
    project_daily_spend