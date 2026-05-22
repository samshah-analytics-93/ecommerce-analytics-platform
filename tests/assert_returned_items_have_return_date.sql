/*
    Test: Items flagged as Returned should have a returned_at timestamp.

    If an item's status is 'Returned' but returned_at is null, the source
    data has an inconsistency. This matters for:
    - Time-to-return analysis
    - Snapshot accuracy (snp_orders tracks returned_at changes)
    - Any future model that uses returned_at for return-window calculations

    Severity: warn (does not block the pipeline — the flag logic is status-
    based, not timestamp-based, so metrics are still correct)
*/

-- dbt test config: severity = warn

select
    order_item_id,
    item_status,
    returned_at,
    item_created_at
from {{ ref('int_order_items_enriched') }}
where is_returned = true
  and returned_at is null
