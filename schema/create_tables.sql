
-- Drop tables in reverse FK dependency order (safe re-run)
DROP TABLE IF EXISTS approvals      CASCADE;
DROP TABLE IF EXISTS payments       CASCADE;
DROP TABLE IF EXISTS invoice_items  CASCADE;
DROP TABLE IF EXISTS invoices       CASCADE;
DROP TABLE IF EXISTS approvers      CASCADE;
DROP TABLE IF EXISTS vendors        CASCADE;
DROP TABLE IF EXISTS companies      CASCADE;
DROP TABLE IF EXISTS currency_rates CASCADE;

-- -------------------------------------------------------------
-- 1. currency_rates
--    No FK dependencies — standalone lookup table
-- -------------------------------------------------------------
CREATE TABLE currency_rates (
    currency    VARCHAR(10)    NOT NULL,
    rate_to_usd NUMERIC(10,6)  NOT NULL CHECK (rate_to_usd > 0),
    rate_date   DATE           NOT NULL,
    PRIMARY KEY (currency, rate_date)
);

-- -------------------------------------------------------------
-- 2. companies
-- -------------------------------------------------------------
CREATE TABLE companies (
    company_id   INTEGER       NOT NULL,
    company_name VARCHAR(200)  NOT NULL,
    industry     VARCHAR(100),
    country      VARCHAR(10),
    PRIMARY KEY (company_id)
);

-- -------------------------------------------------------------
-- 3. vendors
-- -------------------------------------------------------------
CREATE TABLE vendors (
    vendor_id           INTEGER       NOT NULL,
    vendor_name         VARCHAR(200)  NOT NULL,
    vendor_category     VARCHAR(100),
    country             VARCHAR(10),
    payment_terms_days  INTEGER       CHECK (payment_terms_days >= 0),
    PRIMARY KEY (vendor_id)
);

-- -------------------------------------------------------------
-- 4. approvers
-- -------------------------------------------------------------
CREATE TABLE approvers (
    approver_id   INTEGER       NOT NULL,
    approver_name VARCHAR(200)  NOT NULL,
    department    VARCHAR(100),
    level         INTEGER       NOT NULL CHECK (level >= 1),
    PRIMARY KEY (approver_id)
);

-- -------------------------------------------------------------
-- 5. invoices
--    References: companies, vendors, currency_rates
--    status domain: 'submitted' | 'approved' | 'paid'
-- -------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id      INTEGER         NOT NULL,
    company_id      INTEGER         NOT NULL,
    vendor_id       INTEGER         NOT NULL,
    issue_date      DATE            NOT NULL,
    received_date   DATE,
    due_date        DATE            NOT NULL,
    approved_date   DATE,
    paid_date       DATE,
    invoice_amount  NUMERIC(14,2)   NOT NULL CHECK (invoice_amount >= 0),
    currency        VARCHAR(10)     NOT NULL DEFAULT 'USD',
    status          VARCHAR(20)     NOT NULL
                        CHECK (status IN ('submitted', 'approved', 'paid')),
    PRIMARY KEY (invoice_id),
    FOREIGN KEY (company_id)  REFERENCES companies  (company_id),
    FOREIGN KEY (vendor_id)   REFERENCES vendors    (vendor_id)
    -- FK to currency_rates omitted intentionally: rate_date can differ
    -- from invoice dates; currency column is a soft reference.
);

-- -------------------------------------------------------------
-- 6. invoice_items
--    References: invoices
-- -------------------------------------------------------------
CREATE TABLE invoice_items (
    invoice_item_id  INTEGER        NOT NULL,
    invoice_id       INTEGER        NOT NULL,
    category         VARCHAR(100)   NOT NULL,
    amount           NUMERIC(14,2)  NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (invoice_item_id),
    FOREIGN KEY (invoice_id) REFERENCES invoices (invoice_id)
);

-- -------------------------------------------------------------
-- 7. approvals
--    References: invoices, approvers
-- -------------------------------------------------------------
CREATE TABLE approvals (
    approval_id    INTEGER    NOT NULL,
    invoice_id     INTEGER    NOT NULL,
    approver_id    INTEGER    NOT NULL,
    approval_level INTEGER    NOT NULL CHECK (approval_level >= 1),
    approved_at    TIMESTAMP  NOT NULL,
    PRIMARY KEY (approval_id),
    FOREIGN KEY (invoice_id)  REFERENCES invoices  (invoice_id),
    FOREIGN KEY (approver_id) REFERENCES approvers (approver_id)
);

-- -------------------------------------------------------------
-- 8. payments
--    References: invoices
-- -------------------------------------------------------------
CREATE TABLE payments (
    payment_id      INTEGER        NOT NULL,
    invoice_id      INTEGER        NOT NULL,
    payment_method  VARCHAR(100),
    bank_fee        NUMERIC(10,2)  CHECK (bank_fee >= 0),
    PRIMARY KEY (payment_id),
    FOREIGN KEY (invoice_id) REFERENCES invoices (invoice_id)
);

-- -------------------------------------------------------------
-- Indexes for common join / filter columns
-- -------------------------------------------------------------
CREATE INDEX idx_invoices_company      ON invoices      (company_id);
CREATE INDEX idx_invoices_vendor       ON invoices      (vendor_id);
CREATE INDEX idx_invoices_status       ON invoices      (status);
CREATE INDEX idx_invoices_due_date     ON invoices      (due_date);
CREATE INDEX idx_invoice_items_invoice ON invoice_items (invoice_id);
CREATE INDEX idx_approvals_invoice     ON approvals     (invoice_id);
CREATE INDEX idx_approvals_approver    ON approvals     (approver_id);
CREATE INDEX idx_payments_invoice      ON payments      (invoice_id);
