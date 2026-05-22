/*
    Test: Customers with status 'never_ordered' must have zero lifetime value.

    If a never_ordered customer has lifetime_value > 0, the left join or
    coalesce logic in mart_customer_lifetime_value is broken. This would
    mean revenue is being attributed to customers who never purchased.
*/

select
    user_id,
    customer_status,
    lifetime_value,
    total_orders
from {{ ref('mart_customer_lifetime_value') }}
where customer_status = 'never_ordered'
  and (lifetime_value != 0 or total_orders != 0)
