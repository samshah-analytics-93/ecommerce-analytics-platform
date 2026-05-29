{% docs snp_orders %}

## snp_orders

| Property | Value |
|---|---|
| **Grain** | One row per order per status version (SCD Type 2) |
| **Target schema** | `snapshots` |
| **Strategy** | `check` on `status`, `shipped_at`, `delivered_at`, `returned_at` |
| **Source** | `thelook_ecommerce.orders` |

Captures the full lifecycle of an order by recording a new row each time the
tracked columns change.

### dbt-generated columns

| Column | Purpose |
|---|---|
| `dbt_scd_id` | Surrogate key for each version row |
| `dbt_updated_at` | Timestamp when dbt detected the change |
| `dbt_valid_from` | Start of this version's validity window |
| `dbt_valid_to` | End of validity (NULL = current version) |

### Example queries

**Average days from creation to delivery:**
```sql
select
    avg(timestamp_diff(delivered_at, created_at, day)) as avg_days_to_deliver
from analytics_snapshots.snp_orders
where dbt_valid_to is null
  and delivered_at is not null
```

**Orders stuck in Processing for more than 7 days:**
```sql
select order_id, created_at, dbt_updated_at
from analytics_snapshots.snp_orders
where status = 'Processing'
  and dbt_valid_to is null
  and timestamp_diff(current_timestamp(), created_at, day) > 7
```

{% enddocs %}


{% docs snp_users %}

## snp_users

| Property | Value |
|---|---|
| **Grain** | One row per user per profile version (SCD Type 2) |
| **Target schema** | `snapshots` |
| **Strategy** | `check` on `city`, `state`, `country`, `email` |
| **Source** | `thelook_ecommerce.users` |

Tracks changes to customer location and email over time. Useful for
understanding geographic migration patterns and resolving "which location
was the customer in at the time of order?"

Demographic fields (`age`, `gender`) and `traffic_source` are not tracked
because they are immutable registration-time attributes.

{% enddocs %}


{% docs snp_products %}

## snp_products

| Property | Value |
|---|---|
| **Grain** | One row per product per catalog version (SCD Type 2) |
| **Target schema** | `snapshots` |
| **Strategy** | `check` on `name`, `category`, `cost`, `retail_price` |
| **Source** | `thelook_ecommerce.products` |

Tracks changes to product pricing and categorization over time. Useful for
historical margin analysis — joining this snapshot to order items on
`dbt_valid_from`/`dbt_valid_to` gives the cost at the exact time of sale
rather than the current cost.

### dbt-generated columns

| Column | Purpose |
|---|---|
| `dbt_scd_id` | Surrogate key for each version row |
| `dbt_updated_at` | Timestamp when dbt detected the change |
| `dbt_valid_from` | Start of this version's validity window |
| `dbt_valid_to` | End of validity (NULL = current version) |

### Example queries

**Price history for a specific product:**
```sql
SELECT
    id,
    name,
    cost,
    retail_price,
    dbt_valid_from,
    dbt_valid_to
FROM analytics_snapshots.snp_products
WHERE id = 123
ORDER BY dbt_valid_from
```

**Products that have had a price increase:**
```sql
SELECT
    id,
    name,
    retail_price AS current_price,
    LAG(retail_price) OVER (PARTITION BY id ORDER BY dbt_valid_from) AS previous_price
FROM analytics_snapshots.snp_products
WHERE dbt_valid_to IS NULL
```

{% enddocs %}
