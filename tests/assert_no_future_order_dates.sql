/*
    Test: No order items have a created_at date in the future.

    Future-dated items indicate a pipeline bug or timezone misconfiguration.
    If present, they would inflate the current month's revenue in
    mart_order_performance and distort the active-customer window in
    mart_customer_lifetime_value.
*/

select
    order_item_id,
    order_id,
    item_created_at,
    current_timestamp() as checked_at
from {{ ref('stg_order_items') }}
where item_created_at > current_timestamp()
