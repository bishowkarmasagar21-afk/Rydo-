-- Rryd: let the assigned driver record a passenger-agreed destination for pickup-only rides.
CREATE OR REPLACE FUNCTION public.confirm_ride_destination(
  p_ride_id bigint,
  p_destination text,
  p_destination_latitude double precision,
  p_destination_longitude double precision
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ride public.rides%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Please sign in first';
  END IF;

  IF nullif(trim(p_destination), '') IS NULL THEN
    RAISE EXCEPTION 'Destination name or address is required';
  END IF;

  IF p_destination_latitude IS NULL OR p_destination_longitude IS NULL
     OR p_destination_latitude NOT BETWEEN 26 AND 31
     OR p_destination_longitude NOT BETWEEN 80 AND 89 THEN
    RAISE EXCEPTION 'Destination coordinates must be a valid point inside Nepal';
  END IF;

  SELECT *
    INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
    AND driver_id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride not found for this driver';
  END IF;

  IF v_ride.status <> 'arriving'
     OR v_ride.meter_tracking_status <> 'not_started'
     OR v_ride.meter_started_at IS NOT NULL THEN
    RAISE EXCEPTION 'Destination can only be confirmed before the ride meter starts';
  END IF;

  IF nullif(trim(v_ride.destination), '') IS NOT NULL
     OR v_ride.destination_latitude IS NOT NULL
     OR v_ride.destination_longitude IS NOT NULL THEN
    RAISE EXCEPTION 'This ride already has a confirmed destination';
  END IF;

  UPDATE public.rides
  SET destination = trim(p_destination),
      destination_latitude = p_destination_latitude,
      destination_longitude = p_destination_longitude
  WHERE id = p_ride_id
    AND driver_id = v_uid
    AND status = 'arriving'
    AND meter_tracking_status = 'not_started'
    AND destination IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Destination could not be saved; refresh the ride';
  END IF;

  INSERT INTO public.notifications (
    user_id, ride_id, title, message, notification_type
  )
  VALUES (
    v_ride.passenger_id,
    p_ride_id,
    'Ride destination confirmed',
    'Your driver has recorded the destination agreed for this pickup-only ride.',
    'ride_destination_confirmed'
  );

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.confirm_ride_destination(bigint,text,double precision,double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_ride_destination(bigint,text,double precision,double precision) TO authenticated;
