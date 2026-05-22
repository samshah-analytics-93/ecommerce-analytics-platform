{{
config(
    materialized='incremental',
    unique_key='order_item_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

/*
Grain: one row per order item, enriched with product and customer attributes.

This is the single model where:
  1. The three-table join (items × products × users) happens
  2. Status flags are defined
  3. Derived fields (margin, order_month) are computed

If the business adds a new status (e.g. 'Fraud', 'Pending'), update the
flag logic here — every downstream mart picks up the change automatically.
*/

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.user_id,
    oi.product_id,
    oi.item_status,
    oi.sale_price,
    oi.item_created_at,
    oi.returned_at,
    p.product_name,
    p.product_category,
    p.brand,
    p.department,
    p.cost,
    p.retail_price,
    u.acquisition_channel,
    u.country,
    u.city,
    u.state,
    u.gender,
    u.age,
    u.user_created_at,
    CAST(DATE_TRUNC(oi.item_created_at, MONTH) AS DATE) AS order_month,
    DATE(oi.item_created_at) AS order_date,
    oi.sale_price - p.cost AS item_margin,
    CAST(oi.item_status NOT IN ('Cancelled', 'Returned') AS BOOL) AS is_revenue_item,
    CAST(oi.item_status = 'Returned' AS BOOL) AS is_returned,
    CAST(oi.item_status = 'Cancelled' AS BOOL) AS is_cancelled,
    CURRENT_TIMESTAMP() AS warehouse_created_at
FROM {{ ref('stg_order_items') }} oi
INNER JOIN {{ ref('stg_products') }} p
    ON oi.product_id = p.product_id
INNER JOIN {{ ref('stg_users') }} u
    ON oi.user_id = u.user_id

{% if is_incremental() %}
WHERE oi.item_created_at > (SELECT MAX(item_created_at) FROM {{ this }})
{% endif %}
