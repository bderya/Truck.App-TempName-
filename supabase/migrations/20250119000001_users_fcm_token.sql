-- Store FCM device token for push notifications (e.g. new chat message).
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

COMMENT ON COLUMN users.fcm_token IS 'Firebase Cloud Messaging token for push notifications.';
