-- Rryd: serialize ride requests per passenger and reject a second active booking.
CREATE OR REPLACE FUNCTION public.request_ride(
  p_pickup_location text,
  p_destination text,
  p_vehicle_type text,
  p_distance_km numeric,
  p_payment_method text DEFAULT 'cash'::text,
  p_pickup_latitude double precision DEFAULT NULL::double precision,
  p_pickup_longitude double precision DEFAULT NULL::double precision,
  p_destination_latitude double precision DEFAULT NULL::double precision,
  p_destination_longitude double precision DEFAULT NULL::double precision
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_rule public.fare_rules%ROWTYPE;
  v_has_destination boolean;
  v_distance numeric(10,2);
  v_fare numeric(10,2);
  v_ride_id bigint;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first';
  END IF;

  IF nullif(trim(p_pickup_location), '') IS NULL THEN
    RAISE EXCEPTION 'Pickup location is required';
  END IF;

  v_has_destination := nullif(trim(coalesce(p_destination, '')), '') IS NOT NULL;

  IF (p_pickup_latitude IS NULL) <> (p_pickup_longitude IS NULL)
     OR (p_pickup_latitude IS NOT NULL AND
         (p_pickup_latitude NOT BETWEEN 26 AND 31 OR p_pickup_longitude NOT BETWEEN 80 AND 89)) THEN
    RAISE EXCEPTION 'Pickup coordinates must be a valid point inside Nepal';
  END IF;

  IF v_has_destination THEN
    IF p_destination_latitude IS NULL OR p_destination_longitude IS NULL
       OR p_destination_latitude NOT BETWEEN 26 AND 31
       OR p_destination_longitude NOT BETWEEN 80 AND 89 THEN
      RAISE EXCEPTION 'Destination coordinates must be a valid point inside Nepal';
    END IF;
    IF p_distance_km IS NULL OR p_distance_km <= 0 OR p_distance_km > 500 THEN
      RAISE EXCEPTION 'A valid road route is required when a destination is supplied';
    END IF;
    v_distance := round(p_distance_km, 2);
    IF v_distance <= 0 THEN
      RAISE EXCEPTION 'Invalid route distance';
    END IF;
  ELSE
    IF p_destination_latitude IS NOT NULL OR p_destination_longitude IS NOT NULL
       OR p_distance_km IS NOT NULL THEN
      RAISE EXCEPTION 'Destination, destination coordinates and route distance must all be empty for a pickup-only request';
    END IF;
    v_distance := NULL;
  END IF;

  IF p_vehicle_type NOT IN ('bike', 'car', 'tuk_tuk') THEN
    RAISE EXCEPTION 'Invalid vehicle type';
  END IF;

  IF p_payment_method NOT IN ('cash', 'online') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;

  IF p_payment_method = 'online' THEN
    RAISE EXCEPTION 'Online payment is not enabled yet; choose cash';
  END IF;

  -- Lock the passenger profile so simultaneous requests are checked in sequence.
  SELECT *
    INTO v_profile
  FROM public.profiles
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND
     OR v_profile.role <> 'passenger'
     OR COALESCE(v_profile.is_suspended, false) THEN
    RAISE EXCEPTION 'An active passenger account is required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.rides AS r
    WHERE r.passenger_id = v_uid
      AND r.status IN ('requested', 'accepted', 'arriving', 'started')
  ) THEN
    RAISE EXCEPTION 'You already have an active ride';
  END IF;

  SELECT *
    INTO v_rule
  FROM public.fare_rules
  WHERE vehicle_type = p_vehicle_type
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This vehicle type is currently unavailable';
  END IF;

  IF v_has_destination THEN
    v_fare := round(v_rule.base_fare + v_rule.per_km_fare * v_distance, 0);
  ELSE
    v_fare := NULL;
  END IF;

  INSERT INTO public.rides (
    passenger_id,
    pickup_location,
    destination,
    vehicle_type,
    distance_km,
    fare,
    estimated_fare,
    platform_commission_percent,
    base_fare_snapshot,
    per_km_fare_snapshot,
    payment_method,
    payment_status,
    pickup_latitude,
    pickup_longitude,
    destination_latitude,
    destination_longitude,
    meter_tracking_status
  )
  VALUES (
    v_uid,
    trim(p_pickup_location),
    CASE WHEN v_has_destination THEN trim(p_destination) ELSE NULL END,
    p_vehicle_type,
    v_distance,
    v_fare,
    v_fare,
    v_rule.platform_commission_percent,
    v_rule.base_fare,
    v_rule.per_km_fare,
    p_payment_method,
    'pending',
    p_pickup_latitude,
    p_pickup_longitude,
    CASE WHEN v_has_destination THEN p_destination_latitude ELSE NULL END,
    CASE WHEN v_has_destination THEN p_destination_longitude ELSE NULL END,
    'not_started'
  )
  RETURNING id INTO v_ride_id;

  RETURN v_ride_id;
END;
$function$;
