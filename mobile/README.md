# Rryd mobile development

This directory tracks the native mobile-app work. The existing website and admin portal remain in the repository root and are not replaced by mobile work.

## Apps

- Passenger app: `apps/passenger`, Android package `com.rryd.passenger`, iOS bundle ID `com.rryd.passenger`.
- Driver app: `apps/driver`, Android package `com.rryd.driver`, iOS bundle ID `com.rryd.driver`.
- Shared Flutter code: `packages/rryd_core`.

## Product decisions

- Separate Passenger and Driver apps.
- One Supabase Auth identity should be usable in both apps.
- Passenger Settings includes a Become a Driver application.
- Drivers may register multiple vehicles. Each vehicle requires its own approval.
- Driver selects one approved vehicle before going online; driver must go offline to change it.
- A driver may have only one active ride. Server-side validation must enforce this, not just UI checks.
- Ride requests remain available until accepted or cancelled; accepted requests disappear for other drivers.
- Driver search radius expands progressively; proposed starting radii are 3, 5, 8 and 12 km and must be configurable.
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

## Development safety

- Work on the `mobile/flutter-foundation` branch.
- Keep root website/admin files unchanged unless a separate, reviewed change is explicitly needed.
- Use compile-time configuration for Supabase URL and publishable key; no secrets in source.
- Server-side database/RPC validation is authoritative. The client must show real backend errors and never invent success.
- Add tests and CI checks before claiming a build works.
- Do not deploy database migrations or payment changes until the correct live Supabase project is accessible and the migration has been reviewed.
