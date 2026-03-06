
/*
Issue 1
-------
invoice_id = 6 has invoice_amount = -500 SGD.

The value appears to represent a credit note or adjustment.
The CHECK constraint was removed to allow successful import.
*/

ALTER TABLE invoices
DROP CONSTRAINT IF EXISTS invoices_invoice_amount_check;


/*
Issue 2
-------
invoice_id = 21 has NULL due_date in the source CSV.

Constraint relaxed to allow import. This record will be excluded
from late payment calculations.
*/

ALTER TABLE invoices
ALTER COLUMN due_date DROP NOT NULL;



/* ============================================================
   Data Validation Checks
   ============================================================ */


/* ------------------------------------------------------------
   1. Duplicate Invoice IDs
   Expected: 0 rows
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    COUNT(*) AS occurrences
FROM invoices
GROUP BY invoice_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;



/* ------------------------------------------------------------
   2. Paid Before Approval
   Risk: Process control violation
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    approved_date,
    paid_date,
    (paid_date - approved_date) AS days_diff
FROM invoices
WHERE paid_date IS NOT NULL
  AND approved_date IS NOT NULL
  AND paid_date < approved_date
ORDER BY days_diff;



/* ------------------------------------------------------------
   3. Status = 'paid' but paid_date is NULL
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    status,
    paid_date,
    invoice_amount,
    currency
FROM invoices
WHERE status = 'paid'
  AND paid_date IS NULL;



/* ------------------------------------------------------------
   4. Approved/Paid invoices without approval date
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    status,
    approved_date
FROM invoices
WHERE status IN ('approved','paid')
  AND approved_date IS NULL;



/* ------------------------------------------------------------
   5. Orphan Invoice Items
   ------------------------------------------------------------ */

SELECT
    ii.invoice_item_id,
    ii.invoice_id,
    ii.category,
    ii.amount
FROM invoice_items ii
LEFT JOIN invoices i
       ON ii.invoice_id = i.invoice_id
WHERE i.invoice_id IS NULL;



/* ------------------------------------------------------------
   6. Orphan Approvals
   ------------------------------------------------------------ */

SELECT
    a.approval_id,
    a.invoice_id,
    a.approver_id
FROM approvals a
LEFT JOIN invoices  i
       ON a.invoice_id = i.invoice_id
LEFT JOIN approvers ap
       ON a.approver_id = ap.approver_id
WHERE i.invoice_id IS NULL
   OR ap.approver_id IS NULL;



/* ------------------------------------------------------------
   7. Orphan Payments
   ------------------------------------------------------------ */

SELECT
    p.payment_id,
    p.invoice_id,
    p.payment_method,
    p.bank_fee
FROM payments p
LEFT JOIN invoices i
       ON p.invoice_id = i.invoice_id
WHERE i.invoice_id IS NULL;



/* ------------------------------------------------------------
   8. Negative Invoice Amounts
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    invoice_amount,
    currency,
    status
FROM invoices
WHERE invoice_amount < 0;



/* ------------------------------------------------------------
   9. Negative Invoice Item Amounts
   ------------------------------------------------------------ */

SELECT
    invoice_item_id,
    invoice_id,
    category,
    amount
FROM invoice_items
WHERE amount < 0;



/* ------------------------------------------------------------
   10. Invoice Header vs Item Totals
   Tolerance: ±0.01
   ------------------------------------------------------------ */

SELECT
    i.invoice_id,
    i.invoice_amount                      AS header_amount,
    ROUND(SUM(ii.amount)::NUMERIC, 2)     AS items_total,
    ABS(i.invoice_amount - SUM(ii.amount)) AS discrepancy
FROM invoices i
JOIN invoice_items ii
     ON i.invoice_id = ii.invoice_id
GROUP BY i.invoice_id, i.invoice_amount
HAVING ABS(i.invoice_amount - SUM(ii.amount)) > 0.01
ORDER BY discrepancy DESC;



/* ------------------------------------------------------------
   11. due_date earlier than issue_date
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    issue_date,
    due_date,
    (due_date - issue_date) AS days_to_due
FROM invoices
WHERE due_date IS NOT NULL
  AND due_date < issue_date;



/* ------------------------------------------------------------
   12. Missing due_date
   ------------------------------------------------------------ */

SELECT
    invoice_id,
    issue_date,
    due_date,
    status,
    invoice_amount
FROM invoices
WHERE due_date IS NULL;



/* ------------------------------------------------------------
   13. Payments recorded for non-paid invoices
   ------------------------------------------------------------ */

SELECT
    p.payment_id,
    p.invoice_id,
    i.status,
    p.payment_method,
    p.bank_fee
FROM payments p
JOIN invoices i
     ON p.invoice_id = i.invoice_id
WHERE i.status <> 'paid';



/* ------------------------------------------------------------
   14. Paid invoices without payment record
   ------------------------------------------------------------ */

SELECT
    i.invoice_id,
    i.status,
    i.paid_date,
    i.invoice_amount
FROM invoices i
LEFT JOIN payments p
       ON i.invoice_id = p.invoice_id
WHERE i.status = 'paid'
  AND p.payment_id IS NULL;



/* ============================================================
   Data Quality Summary
   ============================================================ */

SELECT
    (SELECT COUNT(*) FROM invoices) AS total_invoices,

    (SELECT COUNT(*)
     FROM invoices
     WHERE paid_date < approved_date
       AND paid_date IS NOT NULL
       AND approved_date IS NOT NULL) AS paid_before_approved,

    (SELECT COUNT(*)
     FROM invoices
     WHERE status = 'paid'
       AND paid_date IS NULL) AS paid_without_date,

    (SELECT COUNT(*)
     FROM invoices
     WHERE status IN ('approved','paid')
       AND approved_date IS NULL) AS approved_without_date,

    (SELECT COUNT(*)
     FROM invoices
     WHERE due_date IS NULL) AS missing_due_date,

    (SELECT COUNT(*)
     FROM invoices
     WHERE invoice_amount < 0) AS negative_invoice_amounts,

    (SELECT COUNT(*)
     FROM invoice_items ii
     LEFT JOIN invoices i
            ON ii.invoice_id = i.invoice_id
     WHERE i.invoice_id IS NULL) AS orphan_invoice_items,

    (SELECT COUNT(*)
     FROM payments p
     LEFT JOIN invoices i
            ON p.invoice_id = i.invoice_id
     WHERE i.invoice_id IS NULL) AS orphan_payments;