{{
config(materialized='table')
}}

/*
Grain: one row per registered customer
Answers: "Who are our top customers by lifetime value?"

Materialization: table (full refresh). Lifetime metrics require a full
scan of all historical items per customer — incremental would need to
reprocess every customer who placed a new order, which at ~100K users
saves negligible compute vs a full rebuild.

The active-customer window uses dbt var('active_customer_days') so it
can be changed in dbt_project.yml without editing SQL.
*/

WITH active_cutoff AS (
    SELECT DATE_SUB(CURRENT_DATE(), INTERVAL {{ var('active_customer_days') }} DAY) AS cutoff_date
),

customer_metrics AS (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(*) AS total_items,
        SUM(sale_price) AS lifetime_revenue,
        SUM(item_margin) AS lifetime_margin,
        AVG(sale_price) AS avg_item_value,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date
    FROM {{ ref('int_order_items_enriched') }}
    WHERE is_revenue_item
    GROUP BY 1
)

SELECT
    u.user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.acquisition_channel,
    u.country,
    u.gender,
    u.age,
    CAST(COALESCE(cm.total_orders, 0) AS INT64) AS total_orders,
    CAST(COALESCE(cm.total_items, 0) AS INT64) AS total_items,
    CAST(ROUND(COALESCE(cm.lifetime_revenue, 0), 2) AS NUMERIC) AS lifetime_value,
    CAST(ROUND(COALESCE(cm.lifetime_margin, 0), 2) AS NUMERIC) AS lifetime_margin,
    CAST(ROUND(COALESCE(cm.avg_item_value, 0), 2) AS NUMERIC) AS avg_item_value,
    cm.first_order_date,
    cm.last_order_date,
    CAST(DATE_DIFF(CURRENT_DATE(), cm.first_order_date, DAY) AS INT64) AS customer_tenure_days,
    CAST(CASE
        WHEN cm.user_id IS NULL THEN 'never_ordered'
        WHEN cm.last_order_date >= ac.cutoff_date THEN 'active'
        ELSE 'lapsed'
    END AS STRING) AS customer_status
FROM {{ ref('stg_users') }} u
LEFT JOIN customer_metrics cm
    ON u.user_id = cm.user_id
CROSS JOIN active_cutoff ac
