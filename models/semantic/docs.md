{% docs semantic_layer %}

## Semantic Layer

The semantic layer defines metrics in one place so that every BI tool, ad-hoc
query, and AI assistant gets the same number for "revenue" or "return rate."

### How It Works

dbt's semantic layer uses [MetricFlow](https://docs.getdbt.com/docs/build/about-metricflow)
to define:

- **Semantic models** — declare the entities (who), dimensions (how to slice),
  and measures (what to aggregate) available in a dbt model.
- **Metrics** — named calculations (simple, derived, or cumulative) built on
  top of measures. These are the things stakeholders actually ask for.

---

### Why We Have a Semantic Layer When Marts Already Exist

The marts and the semantic layer serve different purposes and solve different
problems. They are not redundant — they complement each other.

#### What the Marts Do

The four mart models (`mart_order_performance`, `mart_customer_acquisition`,
`mart_product_category_returns`, `mart_customer_lifetime_value`) are
**pre-aggregated, fixed-grain SQL tables** materialized in BigQuery. Each one
answers a specific, predetermined question:

- `mart_order_performance` — monthly revenue trend
- `mart_customer_acquisition` — one row per acquisition channel
- `mart_product_category_returns` — one row per product category
- `mart_customer_lifetime_value` — one row per customer

Any BI tool can query these directly with plain SQL. They are fast, simple,
and require no additional infrastructure.

#### What the Marts Cannot Do

The fixed grain is also the marts' limitation. They only answer the questions
they were built to answer. Consider:

- "What is revenue by acquisition channel broken down by product category?"
  — no mart has both columns at the same grain.
- "What is the return rate for Female customers in Germany, for the Outerwear
  category, in Q3?" — no mart combines all four dimensions at once.
- "What was revenue growth month-over-month for the Email channel only?"
  — `mart_order_performance` has no channel column.

Every new combination like this would require either a new mart model or a
custom SQL query written from scratch each time — with no guarantee two
analysts write the same logic.

#### What the Semantic Layer Adds

The semantic layer sits on top of `int_order_items_enriched`, which contains
every dimension and every measure at the item level before aggregation. It
does not pre-aggregate — instead it defines the rules for aggregation once,
and computes the correct result for whatever combination is requested at
query time.

**1. Unlimited dimensional slicing without new models**

A BI tool or analyst can request any metric sliced by any dimension declared
in the semantic model — product category, brand, acquisition channel, country,
gender, order month, or any combination — without a new mart being built.
The query is computed on the fly against `int_order_items_enriched`.

**2. A single governed definition for every metric**

Without the semantic layer, "revenue" can mean different things in different
dashboards depending on who wrote the SQL. With the semantic layer, `revenue`
is defined exactly once in `metrics.yml` — sum of `sale_price` where
`is_revenue_item = true`. Every consumer, whether a Tableau dashboard, a
Python notebook, or a dbt Cloud BI chart, gets that exact definition.
Inconsistency across reports becomes structurally impossible.

**3. Direct consumption by BI tools and AI without SQL**

The dbt Cloud Semantic Layer API allows tools like Tableau, Looker, Hex,
and Excel to connect and surface metrics as first-class objects. A business
user selects "Revenue" and "Product Category" in their BI tool — the API
writes the correct SQL against BigQuery and returns the result. No analyst
needs to be involved, and no SQL is written incorrectly.

AI assistants and natural language query tools can also use the semantic
layer as a structured interface — the metric definitions give the AI the
context it needs to answer data questions correctly without hallucinating
SQL logic.

**4. Offset window metrics that marts cannot express cleanly**

`revenue_mom_growth` uses a 1-month offset window, which MetricFlow handles
automatically across any dimensional slice. In the mart, this is hard-coded
as a `LAG()` across the full dataset — it cannot be computed for a specific
channel or category without rewriting the model. The semantic layer computes
it correctly for any slice on demand.

#### The Relationship Between Marts and the Semantic Layer

| | Marts | Semantic Layer |
|---|---|---|
| **Stores data** | Yes, materialized tables in BigQuery | No, metadata only |
| **Query tool required** | Any SQL client | dbt Cloud API or MetricFlow CLI |
| **Grain** | Fixed (pre-defined per model) | Flexible (any dimension combination) |
| **Metric consistency** | Depends on each model's SQL | Guaranteed — one definition in `metrics.yml` |
| **New slice = new model?** | Yes | No |
| **MoM / period comparisons** | Hard-coded per mart | Automatic via offset windows |
| **BI tool integration** | Standard SQL connector | Native semantic layer API |

The marts exist because they are fast, universally accessible, and do not
require any additional infrastructure. Any tool that speaks SQL can use them
today. The semantic layer exists because the marts cannot cover every
question, and governed metric definitions should not be scattered across
dozens of mart models and dashboard SQL snippets.

Both layers are necessary. The marts are the floor — reliable, pre-built
answers to known questions. The semantic layer is the ceiling — a governed
interface for every question that hasn't been anticipated yet.

---

### Semantic Models

| Semantic Model | dbt Model | Grain | Purpose |
|---|---|---|---|
| `order_items` | `int_order_items_enriched` | One row per order item | Core fact model — revenue, volume, return metrics |
| `customers` | `mart_customer_lifetime_value` | One row per customer | Customer dimension — LTV, status, demographics |

### Metrics

| Metric | Type | Description |
|---|---|---|
| `revenue` | Simple | Total `sale_price` for fulfilled items |
| `gross_margin` | Simple | Revenue minus product cost |
| `margin_rate` | Derived | Margin / revenue × 100 |
| `orders` | Simple | Distinct order count |
| `average_order_value` | Derived | Revenue / orders |
| `items_sold` | Simple | Count of fulfilled items |
| `revenue_mom_growth` | Derived | (Current month - prior month) / prior month × 100 |
| `return_rate` | Derived | Returned items / non-cancelled items × 100 |
| `net_revenue` | Derived | Gross revenue - returned revenue |
| `active_customer_count` | Simple | Customers who ordered within active window |
| `customer_lifetime_value` | Simple | Average LTV per customer |
| `revenue_per_customer` | Derived | Revenue / distinct customer count |

### Available Dimensions

All metrics from the `order_items` semantic model can be sliced by:
`product_category`, `brand`, `department`, `acquisition_channel`, `country`,
`gender`, `item_status`, `order_day` (at any time granularity).

Customer metrics can be sliced by: `acquisition_channel`, `country`, `gender`,
`customer_status`, `age`, `first_order_date`.

### Example Queries (via dbt Cloud or MetricFlow CLI)

```bash
# Monthly revenue by channel
mf query --metrics revenue --group-by order_day__month,acquisition_channel

# Return rate by product category
mf query --metrics return_rate --group-by product_category

# Active customer count over time
mf query --metrics active_customer_count --group-by first_order_date__quarter

# Revenue MoM growth for a specific channel — impossible in the marts alone
mf query --metrics revenue_mom_growth --group-by order_day__month,acquisition_channel

# Return rate sliced by gender and country simultaneously
mf query --metrics return_rate --group-by product_category,country,gender
```

{% enddocs %}
