-- Driver onboarding: personal (TCKN, selfie), vehicle (tow type, max weight), payout (IBAN, tax ID).

-- Users: National ID (TCKN), Selfie with License URL, IBAN, Legal Entity/Tax ID
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS national_id TEXT,
  ADD COLUMN IF NOT EXISTS selfie_with_license_url TEXT,
  ADD COLUMN IF NOT EXISTS iban TEXT,
  ADD COLUMN IF NOT EXISTS legal_entity_tax_id TEXT;

COMMENT ON COLUMN users.national_id IS 'Turkish National ID (TCKN) for driver verification.';
COMMENT ON COLUMN users.selfie_with_license_url IS 'Photo: driver holding license (selfie with license).';
COMMENT ON COLUMN users.iban IS 'Driver payout: IBAN for earnings transfer.';
COMMENT ON COLUMN users.legal_entity_tax_id IS 'Optional: Legal entity or tax ID for business accounts.';

-- Tow trucks: physical type (Sliding Bed, Fixed, Crane) and max weight capacity (kg)
ALTER TABLE tow_trucks
  ADD COLUMN IF NOT EXISTS tow_truck_style TEXT,
  ADD COLUMN IF NOT EXISTS max_weight_capacity_kg INTEGER;

COMMENT ON COLUMN tow_trucks.tow_truck_style IS 'Physical type: sliding_bed, fixed, crane.';
COMMENT ON COLUMN tow_trucks.max_weight_capacity_kg IS 'Max weight capacity in kg.';
