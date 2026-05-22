{{
config(materialized='table')
}}

/*
Grain: one row per acquisition channel
Answers: "Which acquisition channels are driving the most revenue?"

Materialization: table (full refresh). Output is ~5 rows — one per
channel — so incremental adds complexity with no practical benefit.
*/

WITH customer_orders AS (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(sale_price) AS lifetime_revenue,
        SUM(item_margin) AS lifetime_margin
    FROM {{ ref('int_order_items_enriched') }}
    WHERE is_revenue_item
    GROUP BY 1
),

customers AS (
    SELECT
        u.user_id,
        u.acquisition_channel,
        COALESCE(co.order_count, 0) AS order_count,
        COALESCE(co.lifetime_revenue, 0) AS lifetime_revenue,
        COALESCE(co.lifetime_margin, 0) AS lifetime_margin
    FROM {{ ref('stg_users') }} u
    LEFT JOIN customer_orders co
        ON u.user_id = co.user_id
)

SELECT
    acquisition_channel,
    CAST(COUNT(*) AS INT64) AS registered_customers,
    CAST(COUNTIF(order_count > 0) AS INT64) AS purchasing_customers,
    CAST(ROUND(SAFE_DIVIDE(COUNTIF(order_count > 0), COUNT(*)) * 100, 2) AS NUMERIC) AS conversion_rate_pct,
    CAST(SUM(order_count) AS INT64) AS total_orders,
    CAST(ROUND(SUM(lifetime_revenue), 2) AS NUMERIC) AS total_revenue,
    CAST(ROUND(SUM(lifetime_margin), 2) AS NUMERIC) AS total_margin,
    CAST(ROUND(SAFE_DIVIDE(SUM(lifetime_revenue), COUNTIF(order_count > 0)), 2) AS NUMERIC) AS revenue_per_buyer,
    CAST(ROUND(SAFE_DIVIDE(SUM(lifetime_revenue), SUM(order_count)), 2) AS NUMERIC) AS avg_order_value
FROM customers
GROUP BY 1
ORDER BY total_revenue DESC
