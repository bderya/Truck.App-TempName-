-- Enable Supabase Realtime for tow_trucks (driver position updates for client tracking)
ALTER PUBLICATION supabase_realtime ADD TABLE tow_trucks;
