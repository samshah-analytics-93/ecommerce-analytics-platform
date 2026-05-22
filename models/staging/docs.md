{% docs src_thelook %}

## TheLook E-Commerce (Source)

Synthetic e-commerce dataset provided by Google as a BigQuery public dataset
(`bigquery-public-data.thelook_ecommerce`). Contains orders, order items,
users, products, inventory, and clickstream events.

This project consumes four of those tables. The `inventory_items` and `events`
tables are available in the source but are not modeled — `events` would be
needed for multi-touch attribution, and `inventory_items` for supply-chain
analysis, neither of which is in scope for this phase.

{% enddocs %}


{% docs stg_orders %}

## stg_orders

| Property | Value |
|---|---|
| **Grain** | One row per order |
| **Materialization** | View |
| **Source** | `thelook_ecommerce.orders` |

Standardizes column names from the raw orders table. All status values are
preserved — no rows are filtered. Downstream models apply their own business
logic via the intermediate layer.

**Why this model exists even though no mart reads from it directly:**
`stg_orders` anchors the referential integrity test on `stg_order_items.order_id`.
Without it, orphaned order items would silently pass through.

**Excluded column:** `gender` is present in the source but is a denormalized
copy of the user's gender. The canonical source is `stg_users.gender`.
Propagating both would create two competing sources for the same attribute.

{% enddocs %}


{% docs stg_order_items %}

## stg_order_items

| Property | Value |
|---|---|
| **Grain** | One row per order item |
| **Materialization** | View |
| **Source** | `thelook_ecommerce.order_items` |

The primary fact table in this project. Every revenue, volume, and return
metric ultimately traces back to this model.

**Critical distinction:** `sale_price` is the amount the customer actually
paid for this item. It is not the same as `retail_price` on `stg_products`,
which is the catalog list price. Revenue must always be calculated from
`sale_price`.

**Item-level vs order-level status:** Both this table and `stg_orders` carry
a `status` column, and they can differ. A single order may have one item
delivered and another returned. All filtering in this project happens at the
item level to avoid discarding fulfilled items from partially-returned orders.

{% enddocs %}


{% docs stg_users %}

## stg_users

| Property | Value |
|---|---|
| **Grain** | One row per registered user |
| **Materialization** | View |
| **Source** | `thelook_ecommerce.users` |

Customer profile and acquisition data. `traffic_source` is renamed to
`acquisition_channel` to match Marketing's terminology.

**Attribution model:** `acquisition_channel` captures the channel at
registration (first-touch). All downstream revenue attribution uses this
value. A customer acquired through Email who later visits directly is still
counted as Email. Multi-touch attribution would require the `events` table.

{% enddocs %}


{% docs stg_products %}

## stg_products

| Property | Value |
|---|---|
| **Grain** | One row per product |
| **Materialization** | View |
| **Source** | `thelook_ecommerce.products` |

Product catalog with category, brand, and pricing data.

**Price fields:**
- `cost` — what the company paid to acquire/manufacture the item
- `retail_price` — the listed catalog price

Neither field represents the actual transaction price. That is `sale_price`
on `stg_order_items`, which accounts for discounts and promotions.

{% enddocs %}
