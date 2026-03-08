-- Enable Supabase Realtime for bookings table
-- Required for driver job request notifications
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
