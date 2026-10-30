# Rryd mobile development

This directory tracks the native mobile-app work. The existing website and admin portal remain in the repository root and are not replaced by mobile work.

## Apps

- Passenger app: `apps/passenger`, Android package `com.rryd.passenger`, iOS bundle ID `com.rryd.passenger`.
- Driver app: `apps/driver`, Android package `com.rryd.driver`, iOS bundle ID `com.rryd.driver`.
- Shared Flutter code: `packages/rryd_core`.

## Product decisions

- Separate Passenger and Driver apps.
- Passenger and Driver are separate app listings. The current database profile has one `role` value (`passenger` or `driver`); simultaneous passenger-and-driver access for one identity requires an explicit backend role design and has not been enabled yet.
- Driver accounts are registered in the Driver app and must be verified by an administrator before going online or accepting a ride.
- Drivers may register multiple vehicles. Each vehicle requires its own approval.
- Any admin-approved vehicle type may qualify the driver for requests of that vehicle type; a single active-vehicle selection rule has not been agreed or implemented.
- The app prevents accepting another ride while an active ride is loaded. The live `accept_ride` function must also enforce this atomically before launch.
- Ride requests are loaded from unassigned `requested` rides. The actual driver SELECT policy and server-side assignment behavior must be verified against the live project.
- Driver search-radius and expansion policy have not been decided; do not hard-code arbitrary radii.
- Cash and digital payments are intended. Digital payment must not be marked paid without verified provider confirmation.
- Current commission reference is 15%; fare values must be read from active `fare_rules`, never hard-coded.
- Fare display rounds to the nearest NPR (0.50 rounds up).
- English and Nepali, manually selectable and persisted separately in each app.
- Initial authentication is the existing Supabase email/password flow, with phone saved as profile contact. SMS OTP is deferred to avoid recurring launch cost.
- SOS, emergency contacts, live trip sharing, push notifications, two-way ratings and driver withdrawals are required product features.

## Existing web integration inventory

The current web passenger portal in `passenger.html` uses:
- `profiles` fields: `id, full_name, phone, role, is_verified, is_suspended`.
- `fare_rules` fields: `vehicle_type, base_fare, per_km_fare, platform_commission_percent, is_active`.
- `rryd_check_vehicle_availability(p_vehicle_type)`.
- `request_ride(p_pickup_location, p_destination, p_vehicle_type, p_distance_km, p_payment_method, p_pickup_latitude, p_pickup_longitude, p_destination_latitude, p_destination_longitude)`.
- `cancel_ride(p_ride_id)`.
- `get_driver_details_for_my_ride(p_ride_id)`.
- `rydd_update_my_passenger_name(p_full_name)`, `rydd_update_my_phone(p_phone)`, and `delete_own_account()`.
- Ride reads use `pickup_location`, `destination`, `pickup_latitude`, `pickup_longitude`, `destination_latitude`, `destination_longitude`, `vehicle_type`, `distance_km`, fare/payment/status fields and timestamps.

The current web driver portal in `driver.html` uses:
- `profiles` and `vehicles` (vehicles read by `driver_id`; fields include `vehicle_type`, `vehicle_model`, `vehicle_number`, `is_approved`).
- `set_driver_online(p_online)`, `accept_ride(p_ride_id)`, `driver_arriving(p_ride_id)`, `start_ride(p_ride_id)`, `complete_ride(p_ride_id)`, `cancel_ride(p_ride_id)`, and `update_driver_location(p_latitude, p_longitude)`.
- Ride request/history queries use `rides`, statuses `requested`, `accepted`, `arriving`, `started`, `completed`, `cancelled`.
- Optional/needs-verification contracts: `notifications`, `ride_messages`, `get_passenger_details_for_my_ride`, and `get_passenger_location_for_my_ride`.

## Important audit findings — do not assume these are resolved

1. The root contains an older `passenger-ride.js` that still writes legacy column names such as `pickup`, `pickup_lat`, and hard-coded fare rates. The current `passenger.html` has a newer inline implementation using `request_ride` and database fare rules. Mobile work must follow the newer RPC contract, not the legacy script.
2. Older standalone `passenger-auth.js`, `driver-auth.js`, and `driver-rides.js` also contain older flows. The current main HTML portals are the reference to verify, but server-side function definitions remain authoritative.
3. Current web code checks a single `profiles.role` value (`passenger` in Passenger and `driver` in Driver). The requested same-account dual-app experience therefore needs a deliberate backend role/eligibility design. Do not change client checks or database schema until the live Supabase schema and function definitions are inspected.
4. Current Passenger web code blocks online payment because no payment gateway is connected. A mobile screen must not claim an online payment was collected until a real provider integration and server-side verification are implemented.
5. Driver passenger-location and notification contracts need to be verified against the live database/RPCs before implementation.
6. The repository code references a Supabase project URL ending in `kqtvuorasqyzjbnlkkxs.supabase.co`. The connected Supabase workspace currently lists only two different projects, both inactive; access to the referenced project has not yet been confirmed. Do not use or restore an older inactive project as a substitute.
7. The repository is public. A publishable Supabase key is intended for client apps but must be protected by correct RLS. Never commit a Supabase secret/service-role key, payment secret, signing key, or private credential.
8. The Nominatim search and OSRM demo routing endpoints are development-only and subject to usage policies/availability. The OpenStreetMap public tile service also has a usage policy; these endpoints are not a contracted production map stack.
9. Passenger/Driver pages are not yet production-ready: native folders and initial flows are being built, but the exact live Supabase project, RLS, role model, deep-link redirect configuration, production geocoder/router, and payment integration must be confirmed.

## Post-trip ratings backend status

- Both mobile apps now expose a rating action for completed trips. A user can submit one rating per ride.
- The reviewed SQL draft is `mobile/sql/rryd_ride_ratings.sql`. It creates an RLS-protected table and `rryd_submit_ride_rating` RPC. Only the passenger and assigned driver can rate each other, and only after the ride is completed.
- The rating UI stays unavailable until the ratings table and RPC exist. Apply the SQL only after the correct production Supabase project is connected and its `rides` schema and RLS have been checked.
- Ratings are immutable from mobile clients in this initial draft. Editing, moderation, public profile averages and admin dispute handling are separate follow-up work.

## Passenger live-location and Driver notification backend status

- Passenger location sharing is implemented as ride-scoped consent: it starts only after a driver is assigned and the ride is `accepted`; it stops when the ride leaves that status. It updates while the Passenger app is active. Background sharing after the app is minimized or closed is not yet implemented.
- The proposed secure backend is in `mobile/sql/rryd_passenger_location_backend.sql`. It creates an RLS-protected location table, passenger update RPC, driver read RPC and cleanup trigger. **This SQL has not been applied to Supabase.** The correct live Supabase project must be connected and the current schema audited before applying it.
- Driver request alerts currently use local notifications when the Driver app is running and polling. True remote/background push when the app is closed requires FCM/APNs setup plus a trusted server-side push sender and credentials; those have not been configured.
- The notification plugin's local notification permission is requested after the driver taps Go online. OS notification settings can still suppress alerts.
- Passenger and Driver accounts still use the existing one-value `profiles.role` model. Cross-app access for a single identity is not enabled by this code alone.

## Development safety

- Work on the `mobile/flutter-foundation` branch.
- Keep root website/admin files unchanged unless a separate, reviewed change is explicitly needed.
- Use compile-time configuration for Supabase URL and publishable key; no secrets in source.
- Server-side database/RPC validation is authoritative. The client must show real backend errors and never invent success.
- Add tests and CI checks before claiming a build works.
- Do not deploy database migrations or payment changes until the correct live Supabase project is accessible and the migration has been reviewed.
