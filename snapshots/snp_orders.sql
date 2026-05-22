{% snapshot snp_orders %}

{{
    config(
        target_schema='snapshots',
        unique_key='order_id',
        strategy='check',
        check_cols=['status', 'shipped_at', 'delivered_at', 'returned_at'],
        invalidate_hard_deletes=True
    )
}}

/*
    SCD Type 2 snapshot of order status transitions.

    Tracks changes to: status, shipped_at, delivered_at, returned_at.
    Each time one of these columns changes, a new row is inserted and
    the prior row's dbt_valid_to is set to the current timestamp.

    Use cases:
    - Average time from order creation to shipment / delivery
    - How long orders sit in "Processing" before advancing
    - Whether returns happen quickly after delivery or weeks later

    Strategy: `check` (compares column values) rather than `timestamp`
    because the source does not have a reliable updated_at column.
*/

SELECT
    order_id,
    user_id,
    status,
    num_of_item,
    created_at,
    shipped_at,
    delivered_at,
    returned_at
FROM {{ source('thelook_ecommerce', 'orders') }}

{% endsnapshot %}
