/*
    Test: No returned items are misclassified as revenue items.

    Mirrors the cancelled-items test but for returns. Returned items had their
    sale_price refunded, so counting them in revenue would overstate the number.
*/

select
    order_item_id,
    item_status,
    is_revenue_item,
    sale_price
from {{ ref('int_order_items_enriched') }}
where item_status = 'Returned'
  and is_revenue_item = true
