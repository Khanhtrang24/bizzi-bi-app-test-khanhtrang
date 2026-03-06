

/* ============================================================
   Metric 1 — Average Approval Time (Days)
   Definition:
   approval_time = approved_date - received_date

   Aggregation:
   Monthly (based on received_date)
   ============================================================ */

SELECT
    TO_CHAR(i.received_date, 'YYYY-MM') AS month,
    COUNT(i.invoice_id) AS invoice_count,
    ROUND(AVG(i.approved_date - i.received_date), 1) AS avg_approval_days,
    MIN(i.approved_date - i.received_date) AS min_days,
    MAX(i.approved_date - i.received_date) AS max_days
FROM invoices i
WHERE i.approved_date IS NOT NULL
  AND i.received_date IS NOT NULL
GROUP BY TO_CHAR(i.received_date, 'YYYY-MM')
ORDER BY month;



/* ============================================================
   Metric 2 — Late Payment Rate
   Definition:
   Late payment = paid_date > due_date
   Scope:
   Paid invoices with valid due_date
   ============================================================ */


/* Overall Late Payment Rate */

SELECT
    COUNT(*) AS total_paid,
    SUM(CASE WHEN paid_date > due_date THEN 1 ELSE 0 END) AS late_count,
    ROUND(
        100.0 * SUM(CASE WHEN paid_date > due_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_pct
FROM invoices
WHERE status = 'paid'
  AND paid_date IS NOT NULL
  AND due_date IS NOT NULL;



/* Monthly Late Payment Trend */

SELECT
    TO_CHAR(due_date, 'YYYY-MM') AS month,
    COUNT(*) AS total_due,
    SUM(CASE WHEN paid_date > due_date THEN 1 ELSE 0 END) AS late_count,
    ROUND(
        100.0 * SUM(CASE WHEN paid_date > due_date THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_pct
FROM invoices
WHERE status = 'paid'
  AND paid_date IS NOT NULL
  AND due_date IS NOT NULL
GROUP BY TO_CHAR(due_date, 'YYYY-MM')
ORDER BY month;



/* ============================================================
   Metric 3 — Invoice Aging Distribution
   Scope:
   Open invoices (status <> 'paid')

   Aging calculation:
   days_overdue = current_date - due_date
   ============================================================ */

WITH aging AS (
    SELECT
        invoice_id,
        invoice_amount,
        currency,
        due_date,
        (CURRENT_DATE - due_date) AS days_overdue,
        CASE
            WHEN CURRENT_DATE <= due_date THEN 'Current'
            WHEN (CURRENT_DATE - due_date) BETWEEN 1 AND 30 THEN '1–30 days'
            WHEN (CURRENT_DATE - due_date) BETWEEN 31 AND 60 THEN '31–60 days'
            WHEN (CURRENT_DATE - due_date) BETWEEN 61 AND 90 THEN '61–90 days'
            ELSE '90+ days'
        END AS aging_bucket
    FROM invoices
    WHERE status <> 'paid'
)

SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    ROUND(SUM(a.invoice_amount * cr.rate_to_usd)::NUMERIC, 2) AS total_usd,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        1
    ) AS pct_of_open
FROM aging a
JOIN currency_rates cr
  ON a.currency = cr.currency
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN 'Current' THEN 1
        WHEN '1–30 days' THEN 2
        WHEN '31–60 days' THEN 3
        WHEN '61–90 days' THEN 4
        ELSE 5
    END;



/* ============================================================
   Metric 4 — Spend by Category (USD)
   Scope:
   Paid invoices only (cash outflow)
   Classification source:
   invoice_items.category
   ============================================================ */

SELECT
    ii.category,
    COUNT(DISTINCT i.invoice_id) AS invoice_count,
    ROUND(SUM(ii.amount * cr.rate_to_usd)::NUMERIC, 2) AS total_spend_usd,
    ROUND(
        100.0 * SUM(ii.amount * cr.rate_to_usd)
        / SUM(SUM(ii.amount * cr.rate_to_usd)) OVER (),
        2
    ) AS pct_of_total
FROM invoice_items ii
JOIN invoices i
  ON ii.invoice_id = i.invoice_id
JOIN currency_rates cr
  ON i.currency = cr.currency
WHERE i.status = 'paid'
GROUP BY ii.category
ORDER BY total_spend_usd DESC;



/* ============================================================
   Metric 5 — Top Vendors by Total Spend
   Scope:
   All invoice statuses (total vendor exposure)
   ============================================================ */

SELECT
    v.vendor_id,
    v.vendor_name,
    v.vendor_category,
    v.country,
    COUNT(DISTINCT i.invoice_id) AS invoice_count,
    ROUND(SUM(i.invoice_amount * cr.rate_to_usd)::NUMERIC, 2) AS total_spend_usd,
    ROUND(
        100.0 * SUM(i.invoice_amount * cr.rate_to_usd)
        / SUM(SUM(i.invoice_amount * cr.rate_to_usd)) OVER (),
        2
    ) AS pct_of_total
FROM invoices i
JOIN vendors v
  ON i.vendor_id = v.vendor_id
JOIN currency_rates cr
  ON i.currency = cr.currency
GROUP BY
    v.vendor_id,
    v.vendor_name,
    v.vendor_category,
    v.country
ORDER BY total_spend_usd DESC
LIMIT 5;





/* Monthly Spend Trend */

SELECT
    TO_CHAR(i.paid_date, 'YYYY-MM') AS month,
    COUNT(i.invoice_id) AS invoices_paid,
    ROUND(SUM(i.invoice_amount * cr.rate_to_usd)::NUMERIC, 2) AS total_spend_usd,
    ROUND(AVG(i.invoice_amount * cr.rate_to_usd)::NUMERIC, 2) AS avg_invoice_usd
FROM invoices i
JOIN currency_rates cr
  ON i.currency = cr.currency
WHERE i.status = 'paid'
  AND i.paid_date IS NOT NULL
GROUP BY TO_CHAR(i.paid_date, 'YYYY-MM')
ORDER BY month;



/* Payment Method Distribution */

SELECT
    payment_method,
    COUNT(*) AS payment_count,
    ROUND(AVG(bank_fee)::NUMERIC, 2) AS avg_bank_fee,
    ROUND(SUM(bank_fee)::NUMERIC, 2) AS total_bank_fee
FROM payments
GROUP BY payment_method
ORDER BY payment_count DESC;



/* Approver Workload */

SELECT
    ap.approver_name,
    ap.department,
    ap.level,
    COUNT(a.approval_id) AS approvals_handled,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (a.approved_at - i.received_date::TIMESTAMP)) / 86400
        )::NUMERIC,
        1
    ) AS avg_days_to_approve
FROM approvals a
JOIN approvers ap
  ON a.approver_id = ap.approver_id
JOIN invoices i
  ON a.invoice_id = i.invoice_id
WHERE i.received_date IS NOT NULL
GROUP BY
    ap.approver_id,
    ap.approver_name,
    ap.department,
    ap.level
ORDER BY approvals_handled DESC;



