{% docs mart_order_performance %}

## mart_order_performance

| Property | Value |
|---|---|
| **Grain** | One row per calendar month |
| **Materialization** | Incremental (merge on `order_month`) |
| **Lookback** | 3 months on incremental runs |
| **Depends on** | `int_order_items_enriched` |

Tracks monthly revenue, order volume, margin, and average order value.
Includes month-over-month change (absolute and percentage) for trend analysis.

**Incremental strategy:** On incremental runs, the last 3 months are
recomputed. This handles two scenarios:
1. Late-arriving items that are assigned to a past month
2. The `lag()` window function for MoM needs the prior month to be current

**What's excluded:** Items where `is_revenue_item = false` (Cancelled or
Returned). A cancelled item was never fulfilled. A returned item's revenue
was refunded.

**Key metrics:**
- `gross_revenue` — sum of `sale_price` for all revenue items
- `gross_margin` — sum of `sale_price - cost`
- `avg_order_value` — revenue / distinct order count
- `margin_pct` — margin as a percentage of revenue
- `revenue_mom_pct_change` — month-over-month revenue change as a percentage

{% enddocs %}


{% docs mart_customer_acquisition %}

## mart_customer_acquisition

| Property | Value |
|---|---|
| **Grain** | One row per acquisition channel |
| **Materialization** | Table (full refresh) |
| **Depends on** | `int_order_items_enriched`, `stg_users` |

Answers "which channels bring us the most valuable customers?" by combining
registration data with purchasing behavior.

**Why `stg_users` is joined again here:** The intermediate model only contains
users who have order items. To calculate `conversion_rate_pct` — the share
of registrations that convert to a purchase — we need all registered users,
including those who never bought anything. Hence the left join back to
`stg_users`.

**Attribution model:** First-touch. A customer's channel is set at
registration and never changes. This is a simplification — multi-touch
attribution would require the `events` table.

**Key metrics:**
- `conversion_rate_pct` — purchasing customers / registered customers × 100
- `revenue_per_buyer` — total revenue / purchasing customers
- `avg_order_value` — total revenue / total orders

{% enddocs %}


{% docs mart_product_category_returns %}

## mart_product_category_returns

| Property | Value |
|---|---|
| **Grain** | One row per product category |
| **Materialization** | Table (full refresh) |
| **Depends on** | `int_order_items_enriched` |

Surfaces which product categories are returned most often and quantifies the
financial impact of those returns.

**Return rate denominator:** All non-cancelled items. Cancelled items are
excluded because they were never shipped and could never be returned. Including
them would artificially deflate return rates.

**Important caveat:** Items currently in Processing or Shipped status may still
be returned in the future. Return rates for recent periods should be read as
a floor estimate, not a final number.

**Key metrics:**
- `return_rate_pct` — returned items / (all non-cancelled items) × 100
- `net_revenue` — gross revenue minus the revenue from returned items
- `net_margin_pct` — margin on non-returned items as a percentage of net revenue

{% enddocs %}


{% docs mart_customer_lifetime_value %}

## mart_customer_lifetime_value

| Property | Value |
|---|---|
| **Grain** | One row per registered customer |
| **Materialization** | Table (full refresh) |
| **Depends on** | `int_order_items_enriched`, `stg_users` |

Every registered user appears in this model, including those who never placed
an order (`lifetime_value = 0`, `customer_status = 'never_ordered'`).

**Customer status definitions:**

| Status | Definition |
|---|---|
| `active` | Placed a fulfilled order within the last N days (default 90) |
| `lapsed` | Has purchased before, but not within the active window |
| `never_ordered` | Registered but never completed a purchase |

The active-customer window is controlled by `var('active_customer_days')` in
`dbt_project.yml`. Changing it once there updates this model automatically.

**Why not incremental:** Lifetime value requires summing all historical items
per customer. An incremental approach would need to reprocess every customer
who placed a new order since the last run. At ~100K users, a full rebuild
runs in under a minute on BigQuery — the complexity of incremental logic
is not justified.

**Tenure vs registration age:** `customer_tenure_days` measures time since
first order, not since account creation. A customer who signed up two years
ago but ordered for the first time last month has a tenure of ~30 days.

{% enddocs %}
