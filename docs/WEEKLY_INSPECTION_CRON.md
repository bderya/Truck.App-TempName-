# Weekly inspection reset (Monday)

Drivers must upload 3 photos of their truck every week. The `is_inspected` flag is reset every Monday so that drivers who have not submitted that week cannot receive jobs until they complete the inspection.

## Option 1: Supabase cron (pg_cron)

If your Supabase project has `pg_cron` enabled:

```sql
SELECT cron.schedule(
  'weekly-reset-inspection',
  '0 1 * * 1',  -- Every Monday at 01:00 UTC
  $$SELECT weekly_reset_inspection()$$
);
```

## Option 2: External cron / GitHub Actions

Call the Supabase REST API or use a Supabase Edge Function that runs on a schedule and executes:

```sql
SELECT weekly_reset_inspection();
```

You can expose this via an RPC or a protected Edge Function that uses the service role key.

## Option 3: Manual

Run in SQL Editor every Monday:

```sql
SELECT weekly_reset_inspection();
```

## Behaviour

- `weekly_reset_inspection()` sets `is_inspected = FALSE` for all tow_trucks.
- Drivers see the "Haftalık muayene gerekli" banner and must open "Fotoğrafları yükle" to submit 3 photos.
- After calling `submit_inspection_photos` RPC with 3 photo URLs, `is_inspected` is set to `TRUE` and they can receive jobs again until the next Monday reset.
