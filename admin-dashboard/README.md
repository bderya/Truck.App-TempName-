# Çekici Master Admin Dashboard

Next.js 14 (App Router) + Tailwind CSS admin panel connected to the same Supabase instance as the Flutter tow-truck app.

## Features

- **Auth**: Email/password login restricted to allowed domains (`NEXT_PUBLIC_ALLOWED_ADMIN_DOMAINS`).
- **Live Map**: react-leaflet map with real-time driver locations and active booking markers (pickup/destination).
- **Approval Pipeline**: Pending drivers list with side-by-side document images (license, criminal record, selfie+license, plate); approve/reject via `approve_user` RPC.
- **Financial Charts**: recharts area chart for daily revenue, platform commission, and payout totals (last 7 days).
- **Real-time Table**: Active bookings table (status not completed/cancelled) updated via Supabase Realtime.

## Setup

1. Copy `.env.local.example` to `.env.local` and set:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_ALLOWED_ADMIN_DOMAINS` (e.g. `company.com,admin.com`)

2. Create admin users in Supabase Auth (Dashboard → Authentication → Users) with email/password. Use an email whose domain is in `ALLOWED_ADMIN_DOMAINS`.

3. Install and run:

```bash
npm install
npm run dev
```

Open http://localhost:3000. Unauthenticated users are redirected to `/login`.

## Tech

- **Next.js 14** (App Router), **Tailwind CSS**
- **Supabase**: Auth (email), Realtime (tow_trucks, bookings), RPC (`approve_user`, etc.)
- **react-leaflet** + **leaflet**: Live map
- **recharts**: Financial area charts
