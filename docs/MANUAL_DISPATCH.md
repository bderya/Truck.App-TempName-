# Manual Dispatch (Admin Assign)

Admins can assign a **pending** job to a specific **online** driver from the dashboard. The driver sees an "Admin Assigned" overlay and taps "Start job" to confirm.

## Database

- **Migration**: `supabase/migrations/20250128000000_manual_dispatch_and_admin_logs.sql`
  - Adds `booking_status` value: `'assigned'` (after pending, before accepted).
  - Creates **admin_logs** table: `id`, `admin_user_id` (UUID), `admin_email`, `action`, `job_id`, `driver_id`, `metadata`, `created_at`.
  - Adds RPC **confirm_admin_assigned_booking(p_booking_id, p_driver_id)** so the driver can move the job from `assigned` → `accepted`.

## Edge Function: manual-assign-job

- **Path**: `supabase/functions/manual-assign-job/index.ts`
- **Invoke**: `POST /functions/v1/manual-assign-job` with body `{ jobId, driverId }` and header `Authorization: Bearer <admin JWT>` (optional; used for audit).
- **Behaviour**:
  1. Validates booking exists and `status = 'pending'`.
  2. Updates `bookings` set `driver_id`, `status = 'assigned'`.
  3. Inserts **admin_logs**: `action = 'manual_assign'`, `job_id`, `driver_id`, `admin_email` from JWT (or `"system"`).
  4. Sends **high-priority FCM** to the driver (if `FCM_SERVER_KEY` and driver `fcm_token` exist).
- **Env**: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` (optional, for resolving admin from JWT), `FCM_SERVER_KEY` (optional).

## Admin Dashboard (Next.js)

- **Pending Jobs table**: New column **"İşlem"** with button **"Atama yap"** for rows with `status === 'pending'`.
- **Assign modal**: Opens with "Manuel atama — İş #id". Fetches **online drivers** from `tow_trucks` where `is_available = true`, joined with `users` for name. Computes **distance** (Haversine) from each truck’s `current_latitude/longitude` to the job’s `pickup_lat/pickup_lng`, sorts by distance. List shows driver name, plate, distance; **"Ata"** calls the Edge Function with current session’s `access_token`.

## Driver App (Flutter)

- **Realtime**: `DriverBookingNotifier` already subscribes to `bookings` INSERT and UPDATE. On **UPDATE** with `status = 'assigned'` and `driver_id = current driver`, it sets state to `PendingJobRequest(..., isAdminAssigned: true)`.
- **Overlay**: When `isAdminAssigned`:
  - Shows message: **"Operatör tarafından size bu iş atandı."**
  - Title: **"Atanan iş"** (no countdown, no decline).
  - Single button: **"İşe başla"** which calls **confirmAdminAssignedJob()** (RPC `confirm_admin_assigned_booking`), then navigates to `JobNavigationScreen` as with normal accept.
- **RPC**: `confirm_admin_assigned_booking(booking_id, driver_id)` checks booking is `assigned` and assigned to that driver, then sets `status = 'accepted'`, `accepted_at = NOW()`.

## Logs

- Every manual assign is stored in **admin_logs** with:
  - `admin_email` (from admin JWT or `"system"`),
  - `action = 'manual_assign'`,
  - `job_id`, `driver_id`,
  - optional `metadata` (e.g. pickup_address).

Query example: `SELECT * FROM admin_logs WHERE action = 'manual_assign' ORDER BY created_at DESC;`

## Flow summary

1. Admin opens **Aktif Rezervasyonlar** → sees pending job → **Atama yap**.
2. Modal lists online drivers by distance → Admin clicks **Ata** for a driver.
3. Edge Function updates booking to `assigned` + driver_id, writes **admin_logs**, sends FCM to driver.
4. Driver app gets Realtime UPDATE → overlay shows "Operatör tarafından size bu iş atandı" and **İşe başla**.
5. Driver taps **İşe başla** → RPC sets status to `accepted` → app navigates to job navigation as usual.
