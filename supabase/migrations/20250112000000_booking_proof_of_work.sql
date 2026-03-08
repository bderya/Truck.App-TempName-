-- Proof of work: pre-pickup damage photos (JSON array of URLs) and delivery signature
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS damage_photos JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS delivery_signature_url TEXT;

COMMENT ON COLUMN bookings.damage_photos IS 'Array of public URLs for pre-pickup vehicle photos (4 required).';
COMMENT ON COLUMN bookings.delivery_signature_url IS 'Public URL of customer signature image at delivery.';
