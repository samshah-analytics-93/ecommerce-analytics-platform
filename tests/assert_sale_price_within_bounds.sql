/*
    Test: No item's sale_price exceeds its retail_price by more than 20%.

    sale_price should generally be at or below retail_price (discounts are
    common; surcharges are not). Items priced significantly above retail
    suggest a data entry error or a join mismatch (wrong product_id).

    Threshold: 20% above retail to allow for minor pricing adjustments
    while catching obvious errors.

    Severity: warn (does not block the pipeline — some edge cases may be
    legitimate promotional pricing)
*/

-- dbt test config: severity = warn

select
    order_item_id,
    product_id,
    product_name,
    sale_price,
    retail_price,
    round(safe_divide(sale_price - retail_price, retail_price) * 100, 2) as pct_above_retail
from {{ ref('int_order_items_enriched') }}
where sale_price > retail_price * 1.20
  and retail_price > 0
