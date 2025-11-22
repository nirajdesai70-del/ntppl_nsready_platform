-- Customer Hierarchy: Add parent_customer_id for hierarchical customer relationships
-- This enables hierarchical organizations like:
--   - Allidhra Group (parent/OEM, parent_customer_id = NULL) - used for grouping/reporting
--   - Allidhra Textool (child customer, parent_customer_id = Allidhra Group UUID) - tenant in v1
--   - Allidhra Texpin (child customer, parent_customer_id = Allidhra Group UUID) - tenant in v1
--
-- NOTE (NSReady v1): Tenant isolation is at company level (tenant_id = customer_id for each company).
-- The parent_customer_id is used for grouping and reporting, not as the tenant boundary.

-- Add parent_customer_id column to customers table
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS parent_customer_id UUID REFERENCES customers(id) ON DELETE CASCADE;

-- Add index for efficient parent-child queries
CREATE INDEX IF NOT EXISTS idx_customers_parent 
ON customers(parent_customer_id) 
WHERE parent_customer_id IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN customers.parent_customer_id IS 
  'Parent customer ID for hierarchical organizations. NULL = top-level customer (OEM/Group). Used for group reporting and aggregation. In NSReady v1, tenant isolation is at company level (tenant_id = customer_id), not at parent level.';

-- NSReady v1 Tenant Model:
--   - tenant_id = customer_id (each individual company is a tenant)
--   - parent_customer_id is used for grouping/reporting only (not tenant boundary)
--   - This enables group reports (all children of a parent) and individual company reports

