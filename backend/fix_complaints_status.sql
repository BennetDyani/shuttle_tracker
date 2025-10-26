-- fix_complaints_status.sql: Ensure complaint_status table has data and complaints are linked

-- ============================================
-- STEP 1: Ensure complaint_status table has default statuses
-- ============================================

-- Insert default complaint statuses if they don't exist
INSERT INTO complaint_status (status_name)
VALUES
  ('OPEN'),
  ('IN_PROGRESS'),
  ('RESOLVED'),
  ('CLOSED')
ON CONFLICT (status_name) DO NOTHING;

-- Show what statuses are available
SELECT 'AVAILABLE_STATUSES' AS tag, * FROM complaint_status ORDER BY status_id;

-- ============================================
-- STEP 2: Fix complaints with NULL status_id
-- ============================================

-- Count complaints with NULL status
SELECT 'COMPLAINTS_WITH_NULL_STATUS' AS tag, COUNT(*) as count
FROM complaints
WHERE status_id IS NULL;

-- Set NULL status_id to OPEN (default)
UPDATE complaints
SET status_id = (SELECT status_id FROM complaint_status WHERE status_name = 'OPEN' LIMIT 1)
WHERE status_id IS NULL;

-- ============================================
-- STEP 3: Verify the fix
-- ============================================

-- Show all complaints with their status names
SELECT 'FIXED_COMPLAINTS' AS tag,
       c.complaint_id,
       c.title,
       c.status_id,
       cs.status_name,
       c.created_at
FROM complaints c
LEFT JOIN complaint_status cs ON c.status_id = cs.status_id
ORDER BY c.created_at DESC;

-- Count complaints by status
SELECT 'COMPLAINTS_BY_STATUS' AS tag,
       COALESCE(cs.status_name, 'NO_STATUS') as status,
       COUNT(*) as count
FROM complaints c
LEFT JOIN complaint_status cs ON c.status_id = cs.status_id
GROUP BY cs.status_name
ORDER BY count DESC;

