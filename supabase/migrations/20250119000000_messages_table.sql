-- Chat messages per booking (client <-> driver).
CREATE TABLE IF NOT EXISTS messages (
  id         BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  sender_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at    TIMESTAMPTZ
);

CREATE INDEX idx_messages_booking_id ON messages(booking_id);
CREATE INDEX idx_messages_created_at ON messages(booking_id, created_at);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- App enforces booking participation; RLS permissive for anon. Tighten with auth.uid() when using Supabase Auth user id in public.users.
CREATE POLICY messages_all ON messages FOR ALL USING (true) WITH CHECK (true);

-- Supabase Realtime: broadcast new/updated messages for chat.
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

COMMENT ON TABLE messages IS 'In-booking chat. read_at set when recipient has seen the message.';
