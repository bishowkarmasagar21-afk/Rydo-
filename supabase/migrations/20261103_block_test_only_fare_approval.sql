-- Rryd Stage 4: prevent test-only or unapproved road matches from finalizing real fares.
-- Live fare approval is intentionally disabled until the production matcher is deployed
-- and writes the exact provider identifier: Rryd production road matcher v1.

CREATE OR REPLACE FUNCTION public.admin_approve_ride_fare(
  p_ride_id bigint,
  p_approval_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ride public.rides%ROWTYPE;
  v_attempt private.ride_meter_verification_attempts%ROWTYPE;
  v_fare numeric(10,2);
  v_commission numeric(10,2);
  v_driver_earnings numeric(10,2);
  v_note text := btrim(coalesce(p_approval_note, ''));
  v_user_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sign in required';
  END IF;

  IF COALESCE(auth.jwt() ->> 'aal', '') <> 'aal2' THEN
    RAISE EXCEPTION 'Administrator multi-factor authentication is required';
  END IF;

  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Active administrator access required';
  END IF;

  IF p_ride_id IS NULL OR p_ride_id <= 0 THEN
    RAISE EXCEPTION 'Invalid ride id';
  END IF;

  IF char_length(v_note) < 8 OR char_length(v_note) > 500 THEN
    RAISE EXCEPTION 'Approval note must be between 8 and 500 characters';
  END IF;

  SELECT *
  INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride not found';
  END IF;

  IF v_ride.status IS DISTINCT FROM 'completed'
     OR v_ride.meter_tracking_status IS DISTINCT FROM 'stopped'
     OR v_ride.meter_started_at IS NULL
     OR v_ride.meter_stopped_at IS NULL
     OR v_ride.completed_at IS NULL THEN
    RAISE EXCEPTION 'Only a completed ride with a stopped GPS meter can be approved';
  END IF;

  IF now() < v_ride.meter_stopped_at + interval '30 minutes' THEN
    RAISE EXCEPTION 'The 30-minute GPS upload window has not closed';
  END IF;

  IF v_ride.fare_approval_status IS DISTINCT FROM 'pending'
     OR v_ride.fare_locked_at IS NOT NULL
     OR v_ride.meter_finalized_at IS NOT NULL
     OR v_ride.final_fare IS NOT NULL THEN
    RAISE EXCEPTION 'This ride fare has already been approved or is not pending approval';
  END IF;

  IF v_ride.driver_id IS NULL OR v_ride.passenger_id IS NULL THEN
    RAISE EXCEPTION 'Ride participant information is incomplete';
  END IF;

  IF v_ride.base_fare_snapshot IS NULL
     OR v_ride.per_km_fare_snapshot IS NULL
     OR v_ride.platform_commission_percent IS NULL
     OR v_ride.platform_commission_percent < 0
     OR v_ride.platform_commission_percent > 100 THEN
    RAISE EXCEPTION 'The ride fare snapshot is incomplete or invalid';
  END IF;

  SELECT *
  INTO v_attempt
  FROM private.ride_meter_verification_attempts
  WHERE ride_id = p_ride_id
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  IF NOT FOUND
     OR v_attempt.provider IS DISTINCT FROM 'Rryd production road matcher v1'
     OR v_attempt.verification_status IS DISTINCT FROM 'matched'
     OR v_attempt.route_distance_km IS NULL
     OR v_attempt.route_distance_km <= 0
     OR v_attempt.sample_count < 5
     OR v_attempt.matched_point_count < 5
     OR v_attempt.unmatched_point_count > floor(v_attempt.sample_count * 0.1)
     OR v_attempt.matched_point_count + v_attempt.unmatched_point_count <> v_attempt.sample_count
     OR v_attempt.minimum_confidence IS NULL
     OR v_attempt.minimum_confidence < 0.5
     OR v_ride.meter_tracking_issue IS TRUE THEN
    RAISE EXCEPTION 'Latest road result is test-only, unapproved, or does not meet verification requirements. Live fare approval is disabled until the production road matcher is configured.';
  END IF;

  -- Nearest whole NPR: decimals below .50 round down; .50 and above round up.
  v_fare := round(
    v_ride.base_fare_snapshot
    + v_ride.per_km_fare_snapshot * v_attempt.route_distance_km,
    0
  );
  v_commission := round(
    v_fare * v_ride.platform_commission_percent / 100,
    2
  );
  v_driver_earnings := v_fare - v_commission;

  UPDATE public.rides
  SET final_fare = v_fare,
      fare = v_fare,
      meter_distance_km = v_attempt.route_distance_km,
      meter_route_distance_km = v_attempt.route_distance_km,
      driver_earnings = v_driver_earnings,
      admin_earnings = v_commission,
      fare_locked_at = now(),
      meter_finalized_at = now(),
      meter_tracking_status = 'finalized',
      fare_approval_status = 'approved',
      fare_approved_by = v_uid,
      fare_approved_at = now(),
      fare_approval_note = v_note,
      meter_tracking_issue = false,
      meter_review_reason = NULL
  WHERE id = p_ride_id;

  INSERT INTO public.rydo_admin_audit_logs
    (admin_id, action, target_table, target_id, details)
  VALUES
    (v_uid, 'ride_fare_approved', 'rides', p_ride_id::text,
     jsonb_build_object(
       'route_distance_km', v_attempt.route_distance_km,
       'final_fare', v_fare,
       'driver_earnings', v_driver_earnings,
       'admin_commission', v_commission,
       'verification_attempt_id', v_attempt.id,
       'approval_note', v_note,
       'verification_provider', v_attempt.provider
     ));

  FOREACH v_user_id IN ARRAY ARRAY[v_ride.passenger_id, v_ride.driver_id]
  LOOP
    INSERT INTO public.notifications
      (user_id, ride_id, title, message, notification_type)
    VALUES
      (
        v_user_id,
        p_ride_id,
        'Ride fare approved',
        'The final Rryd ride fare has been reviewed and approved: NPR ' || v_fare::text || '. Payment is still pending.',
        'ride_fare_approved'
      );
  END LOOP;

  RETURN jsonb_build_object(
    'ride_id', p_ride_id,
    'fare_approval_status', 'approved',
    'route_distance_km', v_attempt.route_distance_km,
    'final_fare', v_fare,
    'driver_earnings', v_driver_earnings,
    'admin_commission', v_commission,
    'payment_status', v_ride.payment_status,
    'payment_collected', false,
    'approved_by', v_uid,
    'approved_at', now()
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_approve_ride_fare(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_approve_ride_fare(bigint, text) TO authenticated, service_role;
