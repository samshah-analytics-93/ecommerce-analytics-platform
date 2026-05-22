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
