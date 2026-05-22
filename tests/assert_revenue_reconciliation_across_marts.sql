/*
    Test: Total revenue in mart_order_performance matches total revenue
    in mart_customer_acquisition.

    Both models should report the same total revenue because they both
    aggregate from int_order_items_enriched with the same filter
    (is_revenue_item = true). If they diverge, either:
    - A filter was accidentally changed in one mart but not the other
    - The join strategy is causing different row counts

    This is the kind of inconsistency the VP of Marketing complained about
    in the original brief. This test prevents it from happening again.

    Tolerance: $0.01 to account for floating-point rounding differences.
*/

with order_perf_total as (
    select round(sum(gross_revenue), 2) as total_revenue
    from {{ ref('mart_order_performance') }}
),

channel_total as (
    select round(sum(total_revenue), 2) as total_revenue
    from {{ ref('mart_customer_acquisition') }}
)

select
    o.total_revenue as order_performance_revenue,
    c.total_revenue as channel_revenue,
    abs(o.total_revenue - c.total_revenue) as discrepancy
from order_perf_total o
cross join channel_total c
where abs(o.total_revenue - c.total_revenue) > 0.01
