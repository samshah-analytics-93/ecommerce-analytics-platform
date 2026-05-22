# ecommerce-analytics-platform

A dbt project built on the [TheLook E-Commerce](https://console.cloud.google.com/marketplace/product/bigquery-public-data/thelook-ecommerce) public dataset hosted in BigQuery. It transforms raw transactional data into a fully tested analytics layer covering revenue, customer lifetime value, product returns, and acquisition channel performance.

---

## Project Structure

```
.
├── dbt_project.yml
├── models/
│   ├── staging/          # Thin wrappers over raw source tables
│   ├── intermediate/     # Enriched join layer shared by all marts
│   ├── marts/            # Aggregated business-facing tables
│   └── semantic/         # MetricFlow semantic models and metrics
├── snapshots/            # SCD Type 2 history tracking
└── tests/                # Singular data quality tests
```

---

## Data Sources

All source data comes from `bigquery-public-data.thelook_ecommerce`.

| Table | Rows | Description |
|---|---|---|
| `orders` | ~100K | One row per order |
| `order_items` | ~300K | One row per item within an order |
| `users` | ~100K | Registered customer profiles |
| `products` | ~30K | Product catalog |

---

## Layers

### Staging

Staging models sit directly on top of the raw source tables. Each one applies:
- **Deduplication** via `ROW_NUMBER()` on the primary key
- **Normalization** — `TRIM`, `INITCAP`, `LOWER` on string fields; `ROUND` on prices
- **`warehouse_created_at`** — `CURRENT_TIMESTAMP()` marking when the record was synced into the warehouse

| Model | Materialization | Unique Key |
|---|---|---|
| `stg_orders` | Incremental (merge) | `order_id` |
| `stg_order_items` | Incremental (merge) | `order_item_id` |
| `stg_users` | Incremental (merge) | `user_id` |
| `stg_products` | View | `product_id` |

### Intermediate

| Model | Materialization | Description |
|---|---|---|
| `int_order_items_enriched` | Incremental (merge) | Joins order items with products and users. Defines `is_revenue_item`, `is_returned`, `is_cancelled` flags and derives `item_margin`, `order_month`, `order_date`. Single source of truth for all mart logic. |

### Marts

| Model | Materialization | Grain | Answers |
|---|---|---|---|
| `mart_order_performance` | Incremental (merge) | One row per calendar month | Monthly revenue, order volume, margin, MoM growth |
| `mart_customer_acquisition` | Table | One row per acquisition channel | Which channels drive the most revenue and conversions |
| `mart_product_category_returns` | Table | One row per product category | Which categories have the highest return rates |
| `mart_customer_lifetime_value` | Table | One row per registered customer | Customer LTV, status (active / lapsed / never_ordered), tenure |

### Semantic Layer

Built with [MetricFlow](https://docs.getdbt.com/docs/build/about-metricflow). Defines 12 metrics on top of two semantic models so every BI tool and ad-hoc query uses the same definitions.

**Semantic models:** `order_items` (fact), `customers` (dimension)

**Metrics:** `revenue`, `gross_margin`, `margin_rate`, `orders`, `average_order_value`, `items_sold`, `revenue_mom_growth`, `return_rate`, `net_revenue`, `active_customer_count`, `customer_lifetime_value`, `revenue_per_customer`

### Snapshots

SCD Type 2 history using dbt's `check` strategy (no `updated_at` in source).

| Snapshot | Tracks changes to |
|---|---|
| `snp_orders` | `status`, `shipped_at`, `delivered_at`, `returned_at` |
| `snp_users` | `city`, `state`, `country`, `email` |

---

## Tests

### Schema tests (defined in `.yml` files)
`unique`, `not_null`, `accepted_values`, `relationships`, `dbt_utils.accepted_range` across all layers.

### Singular tests (in `tests/`)

| Test | What it catches |
|---|---|
| `assert_cancelled_items_not_in_revenue` | Cancelled items leaking into revenue |
| `assert_returned_items_not_in_revenue` | Returned items counted as revenue |
| `assert_revenue_reconciliation_across_marts` | Revenue totals diverging between marts |
| `assert_active_customers_have_recent_orders` | Active customers without a recent order |
| `assert_never_ordered_customers_have_zero_ltv` | Non-buyers with non-zero LTV |
| `assert_returned_items_have_return_date` | Returned status without a `returned_at` timestamp |
| `assert_no_future_order_dates` | Future-dated order items |
| `assert_sale_price_within_bounds` | Sale price more than 20% above retail |

---

## Configuration

### Profile

Add a `ecommerce_analytics` profile to your `~/.dbt/profiles.yml`:

```yaml
ecommerce_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-gcp-project-id
      dataset: analytics_dev
      threads: 4
      timeout_seconds: 300
```

### Variables

| Variable | Default | Description |
|---|---|---|
| `active_customer_days` | `90` | Window (days) used to classify a customer as active in `mart_customer_lifetime_value` |

Override at run time:
```bash
dbt run --vars '{"active_customer_days": 60}'
```

### Schema routing

| Layer | Target schema |
|---|---|
| Staging + Intermediate | `analytics_staging` |
| Marts | `analytics_marts` |
| Snapshots | `analytics_snapshots` |
| Semantic | `analytics_semantic` |

---

## Running the Project

```bash
# Install dependencies
dbt deps

# Run all models
dbt run

# Run a specific layer
dbt run --select staging
dbt run --select intermediate
dbt run --select marts

# Run tests
dbt test

# Run snapshots
dbt snapshot

# Generate and serve docs
dbt docs generate
dbt docs serve

# Check source freshness
dbt source freshness
```

---

## Dependencies

- [dbt-bigquery](https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup)
- [dbt-utils](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/) — used for `accepted_range` tests
