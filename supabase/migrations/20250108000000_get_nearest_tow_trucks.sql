-- RPC: Get nearest available tow trucks within a radius (PostGIS)
-- Call from Flutter: supabase.rpc('get_nearest_available_tow_trucks', params: { p_lat, p_lng, p_radius_km?, p_limit? })

CREATE OR REPLACE FUNCTION get_nearest_available_tow_trucks(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 10,
  p_limit INT DEFAULT 5
)
RETURNS SETOF tow_trucks
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT *
  FROM tow_trucks
  WHERE is_available = TRUE
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000  /* meters */
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  )
  LIMIT p_limit;
$$;
