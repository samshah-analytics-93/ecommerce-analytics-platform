{% docs int_order_items_enriched %}

## int_order_items_enriched

| Property | Value |
|---|---|
| **Grain** | One row per order item |
| **Materialization** | View |
| **Dependencies** | `stg_order_items`, `stg_products`, `stg_users` |

This is the backbone of the analytics layer. It joins the three core staging
models and adds boolean status flags and derived calculations so that mart
models never duplicate join logic or hard-code status strings.

### Status Flags

| Flag | True when | Used for |
|---|---|---|
| `is_revenue_item` | Status is not Cancelled or Returned | Revenue, AOV, LTV calculations |
| `is_returned` | Status is Returned | Return rate calculations |
| `is_cancelled` | Status is Cancelled | Excluding from return rate denominators |

These flags are the **single source of truth** for how the business classifies
item outcomes. If a new status appears in the source data (e.g. `Fraud`),
the `accepted_values` test on `item_status` will fire, and the fix happens
here — not scattered across four mart models.

### Derived Fields

| Field | Definition |
|---|---|
| `order_month` | `date_trunc(item_created_at, month)` — calendar month of the order |
| `order_date` | `date(item_created_at)` — calendar date of the order |
| `item_margin` | `sale_price - cost` — per-item gross margin |

### Join Strategy

Both joins are **inner joins**. This means items with no matching product or
user are dropped. The FK tests on `stg_order_items` (→ `stg_products` and
→ `stg_users`) validate that every key has a match. If those tests pass,
the inner join drops zero rows. If they fail, the test surfaces the problem
before it reaches a report.

### Why View, Not Ephemeral

Four mart models read from this model. If materialized as `ephemeral`, the
full three-table join would be inlined into each mart's compiled SQL —
quadrupling BigQuery compute on every build. As a `view`, the SQL is defined
once and BigQuery optimizes the execution plan across downstream queries.

{% enddocs %}
