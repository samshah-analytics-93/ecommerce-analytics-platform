{% snapshot snp_products %}

{{
    config(
        target_schema='snapshots',
        unique_key='id',
        strategy='check',
        check_cols=['name', 'category', 'cost', 'retail_price'],
        invalidate_hard_deletes=True
    )
}}

/*
    SCD Type 2 snapshot of product catalog changes.

    Tracks changes to: name, category, cost, retail_price.
    Brand and department are treated as immutable classification
    attributes and are NOT tracked here.

    Use cases:
    - Track price changes over time for margin analysis
    - Understand category reclassifications and their revenue impact
    - Historical margin calculations using the cost at time of sale

    Strategy: `check` because the source has no updated_at column.
*/

SELECT
    id,
    name,
    brand,
    category,
    department,
    sku,
    cost,
    retail_price
FROM {{ source('thelook_ecommerce', 'products') }}

{% endsnapshot %}
