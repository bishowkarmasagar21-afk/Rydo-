-- Rryd: serialize ride acceptance per driver to prevent concurrent double-acceptance.
-- The profile row lock is acquired before checking for an existing active ride.
-- The existing ride row lock still prevents two drivers from accepting the same request.

CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ride public.rides%ROWTYPE;
  v_vehicle_id bigint;
  v_locked_driver_id uuid;
  v_now timestamptz := now();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first';
  END IF;

  -- Serialize all accept_ride calls made by this driver.
  SELECT p.id
    INTO v_locked_driver_id
  FROM public.profiles AS p
  WHERE p.id = v_uid
    AND p.role = 'driver'
    AND p.is_verified IS TRUE
    AND p.is_online IS TRUE
    AND COALESCE(p.is_suspended, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verified online driver required';
  END IF;

  -- Lock and validate the requested ride.
  SELECT *
    INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_ride.status <> 'requested'
     OR v_ride.driver_id IS NOT NULL THEN
    RAISE EXCEPTION 'This ride is no longer available';
  END IF;

  -- Do not let one driver accept multiple active rides, including concurrent taps.
  IF EXISTS (
    SELECT 1
    FROM public.rides AS r
    WHERE r.driver_id = v_uid
      AND r.status IN ('accepted', 'arriving', 'started')
  ) THEN
    RAISE EXCEPTION 'You already have an active ride';
  END IF;

  SELECT v.id
    INTO v_vehicle_id
  FROM public.vehicles AS v
  WHERE v.driver_id = v_uid
    AND v.is_approved IS TRUE
    AND v.vehicle_type = v_ride.vehicle_type
  ORDER BY v.id
  LIMIT 1;

  IF v_vehicle_id IS NULL THEN
    RAISE EXCEPTION 'No approved vehicle matching this ride';
  END IF;

  UPDATE public.rides
  SET driver_id = v_uid,
      vehicle_id = v_vehicle_id,
      status = 'accepted',
      accepted_at = v_now,
      meter_started_at = NULL,
      meter_stopped_at = NULL,
      meter_finalized_at = NULL,
      meter_tracking_status = 'not_started',
      meter_point_count = 0,
      meter_tracking_issue = false,
      meter_review_reason = NULL,
      meter_distance_km = NULL,
      meter_route_distance_km = NULL,
      final_fare = NULL,
      fare_locked_at = NULL
  WHERE id = p_ride_id
    AND status = 'requested'
    AND driver_id IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride was accepted by another driver';
  END IF;

  INSERT INTO public.notifications (
    user_id, ride_id, title, message, notification_type
  )
  VALUES (
    v_ride.passenger_id,
    p_ride_id,
    'Driver accepted your ride',
    'Your driver has accepted your Rryd request.',
    'ride_accepted'
  );

  RETURN true;
END;
$function$;
