{{
config(
    materialized='incremental',
    unique_key='product_category',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

/*
Grain: one row per product category
Answers: "Which product categories have the highest return rates?"

Materialization: incremental (merge on product_category). Full scan
of source on every run since return rates depend on all historical
items, but only changed category rows are written back.

Denominator excludes cancelled items (never shipped, not eligible for
return). Numerator counts items flagged as is_returned.

Caveat: items in Processing or Shipped status may still be returned.
Recent return rates should be read as a floor estimate.
*/

WITH non_cancelled_items AS (
    SELECT
        product_category,
        sale_price,
        item_margin,
        is_returned
    FROM {{ ref('int_order_items_enriched') }}
    WHERE NOT is_cancelled
)

SELECT
    product_category,
    CAST(COUNT(*) AS INT64) AS fulfilled_items,
    CAST(COUNTIF(is_returned) AS INT64) AS returned_items,
    CAST(ROUND(SAFE_DIVIDE(COUNTIF(is_returned), COUNT(*)) * 100, 2) AS NUMERIC) AS return_rate_pct,
    CAST(ROUND(SUM(sale_price), 2) AS NUMERIC) AS gross_revenue,
    CAST(ROUND(SUM(CASE WHEN is_returned THEN sale_price ELSE 0 END), 2) AS NUMERIC) AS returned_revenue,
    CAST(ROUND(SUM(CASE WHEN NOT is_returned THEN sale_price ELSE 0 END), 2) AS NUMERIC) AS net_revenue,
    CAST(ROUND(SAFE_DIVIDE(
        SUM(CASE WHEN NOT is_returned THEN item_margin ELSE 0 END),
        SUM(CASE WHEN NOT is_returned THEN sale_price ELSE 0 END)
    ) * 100, 2) AS NUMERIC) AS net_margin_pct
FROM non_cancelled_items
GROUP BY 1
ORDER BY return_rate_pct DESC
