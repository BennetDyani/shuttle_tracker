# Dashboard Issues - Fix Guide

## ✅ FIXED: Students Card
The students card now displays correctly after using `fetchUsersRaw()` to get Map objects instead of User objects.

---

## ⚠️ REMAINING ISSUES TO FIX:

### Issue 1: Drivers Card Shows 2/0 Instead of 4 Drivers

**Current Behavior:** Only 2 drivers are being returned from the API

**To Diagnose:**
1. Open PostgreSQL and connect to your database
2. Run the queries in: `backend/diagnose_dashboard.sql`
3. Check the results for `TOTAL_DRIVERS` and `ALL_DRIVERS` sections

**Expected Results:**
- Should show 4 drivers with their user details
- All drivers should have valid user_id that links to users table

**If Less Than 4 Drivers:**
- Check if the database actually has 4 driver records
- Look for drivers with NULL or invalid user_id
- The backend enriches each driver with user data - if the user_id is invalid, it might fail silently

---

### Issue 2: Complaints Card - Status Always Empty

**Current Behavior:** All complaints have empty status field

**Root Cause:** The backend was querying `SELECT * FROM complaints` without joining with `complaint_status` table

**✅ FIXED IN CODE:**
- Updated `_getAllComplaintsHandler` to JOIN with `complaint_status` table
- Updated `_getComplaintByIdHandler` to include status_name
- Backend now returns `status_name` field for each complaint

**To Complete the Fix:**

1. **Restart the backend server** to apply the code changes
2. **Run the SQL fix script:**
   ```bash
   cd backend
   # Run this SQL file against your database:
   psql -d your_database_name -f fix_complaints_status.sql
   ```

3. **What the SQL script does:**
   - Creates default complaint statuses (OPEN, IN_PROGRESS, RESOLVED, CLOSED)
   - Sets any complaints with NULL status_id to 'OPEN'
   - Verifies all complaints now have valid statuses

4. **Verify the fix:**
   - Refresh the dashboard
   - Check console logs for: `[DEBUG] Complaint status: open` (or other status)
   - Complaints card should now show counts like "2/1" (Open/Resolved)

---

## Files Modified:

### Frontend (Flutter):
- ✅ `lib/services/APIService.dart` - Added `fetchUsersRaw()` method
- ✅ `lib/screens/admin/admin_dashboard.dart` - Uses `fetchUsersRaw()` for proper Map parsing

### Backend (Dart):
- ✅ `backend/bin/server.dart` - Updated complaint handlers to join with complaint_status table

### SQL Scripts Created:
- 📄 `backend/diagnose_dashboard.sql` - Diagnostic queries for drivers and complaints
- 📄 `backend/fix_complaints_status.sql` - Fix script for complaint statuses

---

## Step-by-Step Fix Instructions:

### For Complaints (Do This Now):

1. **Stop the backend server** (if running)

2. **Run the SQL fix:**
   ```bash
   # Option A: Using psql command line
   psql -U postgres -d shuttle_tracker_db -f backend/fix_complaints_status.sql

   # Option B: Copy/paste into pgAdmin or other SQL client
   # Open backend/fix_complaints_status.sql and run all queries
   ```

3. **Restart the backend server:**
   ```bash
   cd backend
   dart run bin/server.dart
   ```

4. **Refresh the Flutter dashboard** - Complaints should now show status

### For Drivers (Diagnose First):

1. **Run diagnostic queries:**
   ```bash
   psql -U postgres -d shuttle_tracker_db -f backend/diagnose_dashboard.sql
   ```

2. **Check the output:**
   - Look for `TOTAL_DRIVERS` - should show 4
   - Look for `ALL_DRIVERS` - should list all 4 drivers with details
   - Check `DRIVERS_NO_USER` and `DRIVERS_NULL_USER` - should be empty

3. **If still only 2 drivers:**
   - Share the SQL output so we can see what's in the database
   - There might be a data issue or the backend query needs adjustment

---

## Expected Final Result:

After applying all fixes, the dashboard should show:

```
┌──────────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────────┐
│  Students    │  │ Drivers(A/S) │  │ Shuttles │  │ Complaints   │
│     16       │  │     4/0      │  │    3     │  │     3        │
└──────────────┘  └──────────────┘  └──────────┘  └──────────────┘
```

And in the console logs:
```
[DEBUG] Complaint status: open
[DEBUG] Complaint status: resolved
[DEBUG] Complaint counts: open=2, resolved=1, total=3
```

---

## Need Help?

If after running the fix scripts:
- Complaints still show empty status → Share the output of fix_complaints_status.sql
- Drivers still show 2/0 → Share the output of diagnose_dashboard.sql
- Any errors occur → Share the error message

The diagnostic scripts will help pinpoint exactly what's wrong!

