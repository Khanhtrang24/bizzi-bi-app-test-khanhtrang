-- -------------------------------------------------------------
-- 1. currency_rates 
-- -------------------------------------------------------------
\copy currency_rates(currency, rate_to_usd, rate_date)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/currency_rates.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 2. companies 
-- -------------------------------------------------------------
\copy companies(company_id, company_name, industry, country)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/companies.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 3. vendors 
-- -------------------------------------------------------------
\copy vendors(vendor_id, vendor_name, vendor_category, country, payment_terms_days)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/vendors.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 4. approvers 
-- -------------------------------------------------------------
\copy approvers(approver_id, approver_name, department, level)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/approvers.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 5. invoices 
-- -------------------------------------------------------------
\copy invoices(invoice_id, company_id, vendor_id, issue_date, received_date,
due_date, approved_date, paid_date, invoice_amount, currency, status)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/invoices.csv'
DELIMITER ',' CSV HEADER NULL '';
-- -------------------------------------------------------------
-- 6. invoice_items 
-- -------------------------------------------------------------
\copy invoice_items(invoice_item_id, invoice_id, category, amount)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/invoice_items.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 7. approvals 
-- -------------------------------------------------------------
\copy approvals(approval_id, invoice_id, approver_id, approval_level, approved_at)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/approvals.csv'
DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------
-- 8. payments 
-- -------------------------------------------------------------
\copy payments(payment_id, invoice_id, payment_method, bank_fee)
FROM '/Users/trang.nguyen/Downloads/bizzi_junior_ap_dataset/payments.csv'
DELIMITER ',' CSV HEADER;
