-- diagnose_dashboard.sql: Check drivers and complaints data for dashboard issues
-- Run this to see what's in the database

-- ============================================
-- PART 1: DRIVERS DIAGNOSIS
-- ============================================
SELECT '=== DRIVERS DIAGNOSIS ===' AS section;

-- Check total drivers
SELECT 'TOTAL_DRIVERS' AS tag, COUNT(*) as count FROM drivers;

-- Show all drivers with user details
SELECT 'ALL_DRIVERS' AS tag,
       d.driver_id,
       d.user_id,
       d.license_number,
       d.phone_number,
       u.email,
       u.first_name,
       u.last_name,
       r.role_name
FROM drivers d
LEFT JOIN users u ON d.user_id = u.user_id
LEFT JOIN roles r ON u.role_id = r.role_id
ORDER BY d.driver_id;

-- Check for drivers with missing user records
SELECT 'DRIVERS_NO_USER' AS tag, *
FROM drivers
WHERE user_id NOT IN (SELECT user_id FROM users);

-- Check for drivers with NULL user_id
SELECT 'DRIVERS_NULL_USER' AS tag, *
FROM drivers
WHERE user_id IS NULL;

-- ============================================
-- PART 2: COMPLAINTS DIAGNOSIS
-- ============================================
SELECT '=== COMPLAINTS DIAGNOSIS ===' AS section;

-- Check complaint_status table
SELECT 'COMPLAINT_STATUSES' AS tag, * FROM complaint_status ORDER BY status_id;

-- Show all complaints with status names
SELECT 'ALL_COMPLAINTS_WITH_STATUS' AS tag,
       c.complaint_id,
       c.user_id,
       c.title,
       c.status_id,
       cs.status_name,
       c.created_at
FROM complaints c
LEFT JOIN complaint_status cs ON c.status_id = cs.status_id
ORDER BY c.created_at DESC;

-- Check for complaints with NULL status_id
SELECT 'COMPLAINTS_NO_STATUS' AS tag, COUNT(*) as count
FROM complaints
WHERE status_id IS NULL;

-- ============================================
-- PART 3: QUICK FIXES (IF NEEDED)
-- ============================================

-- If complaint_status table is empty, insert default statuses
INSERT INTO complaint_status (status_name)
VALUES ('OPEN'), ('IN_PROGRESS'), ('RESOLVED'), ('CLOSED')
ON CONFLICT DO NOTHING;

-- If complaints have NULL status_id, set them to OPEN (status_id 1)
UPDATE complaints
SET status_id = (SELECT status_id FROM complaint_status WHERE status_name = 'OPEN' LIMIT 1)
WHERE status_id IS NULL;

