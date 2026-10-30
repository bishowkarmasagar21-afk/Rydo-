-- Rryd passenger live-location sharing
-- Prepared for review. Do not apply to production until the active Rryd
-- Supabase project/schema has been inspected and this migration is approved.
--
-- Security model:
--   * Passenger may write a location only for their own assigned ride while
--     its status is 'accepted'.
--   * Assigned driver may read only that ride's fresh location while status
--     remains 'accepted'.
--   * No anon access. RLS is enabled. RPC functions use SECURITY INVOKER.
--   * Location rows are deleted when the ride status leaves 'accepted'.

create table if not exists public.ride_passenger_locations (
  ride_id bigint primary key references public.rides(id) on delete cascade,
  passenger_id uuid not null references auth.users(id) on delete cascade,
  latitude double precision not null
    check (latitude between 26 and 31),
  longitude double precision not null
    check (longitude between 80 and 89),
  updated_at timestamptz not null default pg_catalog.now()
);

alter table public.ride_passenger_locations enable row level security;

revoke all on table public.ride_passenger_locations from anon;
grant select, insert, update, delete
  on table public.ride_passenger_locations to authenticated;

drop policy if exists "passenger and assigned driver read shared ride location"
  on public.ride_passenger_locations;
create policy "passenger and assigned driver read shared ride location"
  on public.ride_passenger_locations
  for select
  to authenticated
  using (
    passenger_id = (select auth.uid())
    or exists (
      select 1
      from public.rides as r
      where r.id = ride_passenger_locations.ride_id
        and r.driver_id = (select auth.uid())
        and r.status = 'accepted'
    )
  );

drop policy if exists "passenger writes own accepted ride location"
  on public.ride_passenger_locations;
create policy "passenger writes own accepted ride location"
  on public.ride_passenger_locations
  for insert
  to authenticated
  with check (
    passenger_id = (select auth.uid())
    and exists (
      select 1
      from public.rides as r
      where r.id = ride_passenger_locations.ride_id
        and r.passenger_id = (select auth.uid())
        and r.driver_id is not null
        and r.status = 'accepted'
    )
  );

drop policy if exists "passenger updates own accepted ride location"
  on public.ride_passenger_locations;
create policy "passenger updates own accepted ride location"
  on public.ride_passenger_locations
  for update
  to authenticated
  using (
    passenger_id = (select auth.uid())
    and exists (
      select 1
      from public.rides as r
      where r.id = ride_passenger_locations.ride_id
        and r.passenger_id = (select auth.uid())
        and r.driver_id is not null
        and r.status = 'accepted'
    )
  )
  with check (
    passenger_id = (select auth.uid())
    and exists (
      select 1
      from public.rides as r
      where r.id = ride_passenger_locations.ride_id
        and r.passenger_id = (select auth.uid())
        and r.driver_id is not null
        and r.status = 'accepted'
    )
  );

drop policy if exists "passenger or assigned driver deletes ended ride location"
  on public.ride_passenger_locations;
create policy "passenger or assigned driver deletes ended ride location"
  on public.ride_passenger_locations
  for delete
  to authenticated
  using (
    passenger_id = (select auth.uid())
    or exists (
      select 1
      from public.rides as r
      where r.id = ride_passenger_locations.ride_id
        and r.driver_id = (select auth.uid())
        and r.status <> 'accepted'
    )
  );

create or replace function public.rryd_update_my_passenger_location(
  p_ride_id bigint,
  p_latitude double precision,
  p_longitude double precision
)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_updated_ride_id bigint;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.';
  end if;

  if p_ride_id is null
     or p_latitude is null
     or p_longitude is null
     or p_latitude not between 26 and 31
     or p_longitude not between 80 and 89 then
    raise exception 'A valid Nepal location is required.';
  end if;

  insert into public.ride_passenger_locations (
    ride_id,
    passenger_id,
    latitude,
    longitude,
    updated_at
  )
  select
    r.id,
    (select auth.uid()),
    p_latitude,
    p_longitude,
    pg_catalog.now()
  from public.rides as r
  where r.id = p_ride_id
    and r.passenger_id = (select auth.uid())
    and r.driver_id is not null
    and r.status = 'accepted'
  on conflict (ride_id) do update
    set passenger_id = excluded.passenger_id,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        updated_at = pg_catalog.now()
    where public.ride_passenger_locations.passenger_id = (select auth.uid())
  returning ride_id into v_updated_ride_id;

  return v_updated_ride_id is not null;
end;
$$;

create or replace function public.rryd_get_passenger_location_for_my_ride(
  p_ride_id bigint
)
returns table (
  latitude double precision,
  longitude double precision,
  updated_at timestamptz
)
language sql
stable
set search_path = ''
as $$
  select
    l.latitude,
    l.longitude,
    l.updated_at
  from public.ride_passenger_locations as l
  join public.rides as r on r.id = l.ride_id
  where r.id = p_ride_id
    and r.driver_id = (select auth.uid())
    and r.status = 'accepted'
    and l.updated_at >= pg_catalog.now() - interval '2 minutes';
$$;

revoke all on function public.rryd_update_my_passenger_location(
  bigint, double precision, double precision
) from public, anon;
grant execute on function public.rryd_update_my_passenger_location(
  bigint, double precision, double precision
) to authenticated;

revoke all on function public.rryd_get_passenger_location_for_my_ride(
  bigint
) from public, anon;
grant execute on function public.rryd_get_passenger_location_for_my_ride(
  bigint
) to authenticated;

create or replace function public.rryd_cleanup_passenger_location_after_ride_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and new.status <> 'accepted' then
    delete from public.ride_passenger_locations
    where ride_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists rryd_cleanup_passenger_location_after_ride_status
  on public.rides;
create trigger rryd_cleanup_passenger_location_after_ride_status
after update of status on public.rides
for each row
execute function public.rryd_cleanup_passenger_location_after_ride_status();

revoke all on function public.rryd_cleanup_passenger_location_after_ride_status()
  from public, anon;
