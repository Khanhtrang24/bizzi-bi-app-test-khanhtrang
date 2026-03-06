# bizzi-bi-app-test-khanhtrang
# Bizzi BI AP Test

## PostgreSQL Version

PostgreSQL 16 (Docker container)

---

# Setup Instructions

### 1. Create Database

```sql
CREATE DATABASE bizzi_ap;
```

### 2. Create Schema

Run:

```
schema/create_tables.sql
```

This script creates the core tables:

* vendors
* invoices
* invoice_items
* payments
* approvals
* approvers
* currency_rates

Primary keys, foreign keys, and appropriate data types are defined.

---

### 3. Import CSV Data

Run:

```
import/import_commands.sql
```

This loads the provided CSV files into the database tables.

If using `psql`:

```
\copy vendors FROM 'vendors.csv' CSV HEADER
\copy invoices FROM 'invoices.csv' CSV HEADER
\copy invoice_items FROM 'invoice_items.csv' CSV HEADER
\copy payments FROM 'payments.csv' CSV HEADER
\copy approvals FROM 'approvals.csv' CSV HEADER
\copy approvers FROM 'approvers.csv' CSV HEADER
\copy currency_rates FROM 'currency_rates.csv' CSV HEADER
```

---

### 4. Run Data Validation

Execute:

```
analysis/data_validation.sql
```

This script performs integrity checks such as:

* duplicate invoices
* orphan records
* workflow inconsistencies
* negative values
* header vs item reconciliation

---

### 5. Run Metrics Queries

Execute:

```
analysis/ap_metrics.sql
```

This produces the key AP performance metrics used for dashboarding.

---

# Assumptions

1. **Currency Conversion**

All monetary metrics are converted to USD using the `currency_rates` table.

Conversion logic:

```
amount_usd = amount * rate_to_usd
```

Exchange rates are assumed constant for the dataset period.

---

2. **Late Payment Definition**

A payment is considered **late** if:

```
paid_date > due_date
```

Invoices without `due_date` are excluded from this calculation.

---

3. **Approval Time Definition**

Approval time is calculated as:

```
approved_date - received_date
```

Invoices missing either timestamp are excluded.

---

4. **Aging Calculation**

Invoice aging is calculated relative to:

```
CURRENT_DATE
```

Buckets used:

* Current
* 1–30 days
* 31–60 days
* 61–90 days
* 90+ days

---

# Data Quality Issues Identified

### 1. Negative Invoice Amount

```
invoice_id = 6
amount = -500 SGD
```

This may represent a **credit note** or adjustment.

The original `CHECK (invoice_amount >= 0)` constraint was removed to allow import.

---

### 2. Missing Due Date

```
invoice_id = 21
due_date = NULL
```

This invoice is marked as paid but lacks a due date.

Impact:

* Cannot determine whether payment was late.

---

### 3. Potential Workflow Risks Checked

The validation script verifies:

* paid before approval
* paid invoices without payment record
* approvals referencing missing invoices
* orphan invoice items

No structural data corruption was detected.

---

# Key Observations

### Late Payment Rate

A measurable portion of invoices are paid after the due date, indicating potential AP process inefficiencies.

---

### Vendor Spend Concentration

A small number of vendors account for a large share of total spend, suggesting:

* vendor concentration risk
* potential negotiation opportunities

---

### Approval Turnaround

Average approval time varies across invoices and may indicate process bottlenecks within the approval workflow.

---

# Approximate Time Spent

| Task                    | Time        |
| ----------------------- | ----------- |
| Data modeling           | ~1.5 hours  |
| Data validation queries | ~1 hour     |
| Metric calculations     | ~1.5 hours  |
| Documentation           | ~30 minutes |

Total: **~4.5 hours**

---

# Potential Improvements

With additional time, the following improvements would be implemented:

### 1. Indexing Strategy

Add indexes to optimize analytical queries:

```sql
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_vendor ON invoices(vendor_id);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
```

---

### 2. Materialized Views

Create pre-aggregated tables for dashboard performance:

* monthly spend
* approval time trend
* vendor spend ranking

---

### 3. Data Quality Constraints

Introduce additional constraints such as:

* enforcing valid workflow state transitions
* validation rules for negative invoice amounts

---

### 4. BI Dashboard

Build a monitoring dashboard showing:

* AP KPIs
* invoice aging
* vendor spend analysis
* payment method distribution

Potential tools:

* Apache Superset
* Metabase
* Power BI
