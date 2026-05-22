{% docs singular_tests %}

## Singular Tests

These SQL-based tests validate business logic that generic tests (`unique`,
`not_null`, `accepted_values`) cannot express. Each file returns rows that
violate an assertion — zero rows means the test passes.

### Revenue Integrity

| Test | What It Catches |
|---|---|
| `assert_cancelled_items_not_in_revenue` | Cancelled items leaking into revenue (overstates top line) |
| `assert_returned_items_not_in_revenue` | Returned items counted as revenue (overstates top line) |
| `assert_revenue_reconciliation_across_marts` | Revenue totals diverging between marts (inconsistent reports) |

These three tests together prevent the exact problem described in the brief:
"Revenue figures don't match across reports." If all three pass, every mart
is computing revenue from the same filtered population.

### Status & Classification Integrity

| Test | What It Catches |
|---|---|
| `assert_active_customers_have_recent_orders` | Customers flagged as 'active' without a recent order |
| `assert_never_ordered_customers_have_zero_ltv` | Non-buyers with non-zero revenue attribution |
| `assert_returned_items_have_return_date` | Data inconsistency: returned status without a timestamp |

### Data Quality

| Test | What It Catches |
|---|---|
| `assert_no_future_order_dates` | Pipeline bug or timezone misconfiguration |
| `assert_sale_price_within_bounds` | Likely data entry error or product_id mismatch |

### Severity Levels

Most tests are `severity: error` (block the pipeline). Two are `severity: warn`:
- `assert_returned_items_have_return_date` — metrics are status-based, so
  a missing timestamp does not affect accuracy, but it should be investigated.
- `assert_sale_price_within_bounds` — some edge cases may be legitimate.

{% enddocs %}
