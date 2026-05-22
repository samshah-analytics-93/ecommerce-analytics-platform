/*
    Test: No cancelled items leak into revenue calculations.

    The intermediate model marks cancelled items with is_revenue_item = false.
    This test validates that assertion by checking if any cancelled item was
    incorrectly flagged as a revenue item. If this returns rows, the flag
    logic in int_order_items_enriched is broken.

    Why this matters: if cancelled items count as revenue, every revenue
    metric in the project is overstated. This is the single most impactful
    data quality issue to catch.
*/

select
    order_item_id,
    item_status,
    is_revenue_item,
    sale_price
from {{ ref('int_order_items_enriched') }}
where item_status = 'Cancelled'
  and is_revenue_item = true
