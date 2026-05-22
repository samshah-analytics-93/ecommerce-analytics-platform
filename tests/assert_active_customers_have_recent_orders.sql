/*
    Test: Every customer flagged as 'active' has a last_order_date within
    the active-customer window.

    Validates that the customer_status case statement in
    mart_customer_lifetime_value correctly implements the active-window
    logic. If this fails, the active/lapsed classification is broken
    and any dashboard showing "active customer count" is wrong.
*/

select
    user_id,
    customer_status,
    last_order_date,
    date_sub(current_date(), interval {{ var('active_customer_days') }} day) as cutoff_date
from {{ ref('mart_customer_lifetime_value') }}
where customer_status = 'active'
  and last_order_date < date_sub(current_date(), interval {{ var('active_customer_days') }} day)
