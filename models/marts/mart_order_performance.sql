{{
config(
    materialized='incremental',
    unique_key='order_month',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

/*
Grain: one row per calendar month (UTC)
Answers: "What is our monthly order volume and revenue trend?"

Materialization: incremental (merge on order_month).
On incremental runs, the last 3 months are recomputed to capture
late-arriving items and keep MoM calculations accurate.
*/

WITH monthly_aggregates AS (
    SELECT
        order_month,
        COUNT(DISTINCT order_id) AS order_count,
        COUNT(*) AS item_count,
        SUM(sale_price) AS gross_revenue,
        SUM(item_margin) AS gross_margin
    FROM {{ ref('int_order_items_enriched') }}
    WHERE is_revenue_item

    {% if is_incremental() %}
    AND order_month >= DATE_SUB(
        (SELECT MAX(order_month) FROM {{ this }}),
        INTERVAL 3 MONTH
    )
    {% endif %}

    GROUP BY 1
),

with_prior_month AS (
    SELECT
        *,
        LAG(gross_revenue) OVER (ORDER BY order_month) AS prior_month_revenue
    FROM monthly_aggregates
)

SELECT
    order_month,
    CAST(order_count AS INT64) AS order_count,
    CAST(item_count AS INT64) AS item_count,
    CAST(ROUND(gross_revenue, 2) AS NUMERIC) AS gross_revenue,
    CAST(ROUND(gross_margin, 2) AS NUMERIC) AS gross_margin,
    CAST(ROUND(SAFE_DIVIDE(gross_revenue, order_count), 2) AS NUMERIC) AS avg_order_value,
    CAST(ROUND(SAFE_DIVIDE(gross_margin, gross_revenue) * 100, 2) AS NUMERIC) AS margin_pct,
    CAST(ROUND(gross_revenue - prior_month_revenue, 2) AS NUMERIC) AS revenue_mom_change,
    CAST(ROUND(SAFE_DIVIDE(gross_revenue - prior_month_revenue, prior_month_revenue) * 100, 2) AS NUMERIC) AS revenue_mom_pct_change
FROM with_prior_month
