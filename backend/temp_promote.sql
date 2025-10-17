-- temp_promote.sql: inspect user, staff, insert staff row if missing, and show admins view
SELECT 'USER' AS tag, user_id, email FROM users WHERE email = 'kabelomomo@hgtsadmin.cput.com';

SELECT 'STAFF_BEFORE' AS tag, * FROM staff WHERE user_id IN (SELECT user_id FROM users WHERE email = 'kabelomomo@hgtsadmin.cput.com');

-- Insert staff row if missing, generate staff_id as 'ADMIN' || user_id
INSERT INTO staff (user_id, staff_id)
SELECT u.user_id, ('ADMIN' || u.user_id::text) AS staff_id
FROM users u
WHERE u.email = 'kabelomomo@hgtsadmin.cput.com'
  AND NOT EXISTS (SELECT 1 FROM staff s WHERE s.user_id = u.user_id);

SELECT 'STAFF_AFTER' AS tag, * FROM staff WHERE user_id IN (SELECT user_id FROM users WHERE email = 'kabelomomo@hgtsadmin.cput.com');

-- Show admins view
SELECT 'ADMINS_VIEW' AS tag, * FROM admins LIMIT 10;

