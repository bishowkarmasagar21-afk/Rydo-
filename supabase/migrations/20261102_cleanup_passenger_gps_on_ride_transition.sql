-- Rryd: remove live passenger GPS immediately when a ride leaves the accepted state.
CREATE OR REPLACE FUNCTION public.rryd_cleanup_passenger_location_after_ride_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM 'accepted'
     OR NEW.driver_id IS NULL
     OR OLD.status IS DISTINCT FROM NEW.status
     OR OLD.driver_id IS DISTINCT FROM NEW.driver_id THEN
    DELETE FROM public.passenger_ride_locations
    WHERE ride_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS rryd_cleanup_passenger_location_after_ride_change
ON public.rides;

CREATE TRIGGER rryd_cleanup_passenger_location_after_ride_change
AFTER UPDATE OF status, driver_id ON public.rides
FOR EACH ROW
EXECUTE FUNCTION public.rryd_cleanup_passenger_location_after_ride_change();

REVOKE ALL ON FUNCTION public.rryd_cleanup_passenger_location_after_ride_change() FROM PUBLIC, anon, authenticated;
