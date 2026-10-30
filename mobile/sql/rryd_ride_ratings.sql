-- Rryd two-way post-trip ratings
-- REVIEW DRAFT ONLY. Do not apply until the active production Supabase
-- project and current rides schema have been verified.
--
-- One rating per participant per completed ride:
--   passenger rates assigned driver
--   assigned driver rates passenger
-- Ratings cannot be edited or deleted by mobile clients.

create table if not exists public.ride_ratings (
  id uuid primary key default gen_random_uuid(),
  ride_id bigint not null
    references public.rides(id) on delete cascade,
  reviewer_id uuid not null
    references auth.users(id) on delete cascade,
  reviewee_id uuid not null
    references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  feedback text null
    check (feedback is null or char_length(feedback) <= 1000),
  created_at timestamptz not null default pg_catalog.now(),
  constraint ride_ratings_one_rating_per_reviewer
    unique (ride_id, reviewer_id),
  constraint ride_ratings_participants_must_differ
    check (reviewer_id <> reviewee_id)
);

create index if not exists ride_ratings_reviewee_created_idx
  on public.ride_ratings (reviewee_id, created_at desc);

alter table public.ride_ratings enable row level security;

revoke all on table public.ride_ratings from anon, public;
grant select, insert on table public.ride_ratings to authenticated;

drop policy if exists "ride participants read their ratings"
  on public.ride_ratings;
create policy "ride participants read their ratings"
  on public.ride_ratings
  for select
  to authenticated
  using (
    reviewer_id = (select auth.uid())
    or reviewee_id = (select auth.uid())
  );

drop policy if exists "completed ride participant submits one rating"
  on public.ride_ratings;
create policy "completed ride participant submits one rating"
  on public.ride_ratings
  for insert
  to authenticated
  with check (
    reviewer_id = (select auth.uid())
    and exists (
      select 1
      from public.rides as r
      where r.id = ride_ratings.ride_id
        and r.status = 'completed'
        and (
          (
            r.passenger_id = (select auth.uid())
            and r.driver_id = ride_ratings.reviewee_id
          )
          or
          (
            r.driver_id = (select auth.uid())
            and r.passenger_id = ride_ratings.reviewee_id
          )
        )
    )
  );

create or replace function public.rryd_submit_ride_rating(
  p_ride_id bigint,
  p_rating smallint,
  p_feedback text default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_passenger_id uuid;
  v_driver_id uuid;
  v_status text;
  v_reviewee_id uuid;
  v_rating_id uuid;
  v_feedback text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  v_feedback := nullif(pg_catalog.btrim(p_feedback), '');
  if v_feedback is not null and pg_catalog.char_length(v_feedback) > 1000 then
    raise exception 'Feedback must be at most 1000 characters.';
  end if;

  select r.passenger_id, r.driver_id, r.status
    into v_passenger_id, v_driver_id, v_status
  from public.rides as r
  where r.id = p_ride_id;

  if not found then
    raise exception 'Ride was not found.';
  end if;

  if v_status <> 'completed' then
    raise exception 'A rating can only be submitted after ride completion.';
  end if;

  if v_driver_id is null then
    raise exception 'A completed ride must have an assigned driver to be rated.';
  end if;

  if v_user_id = v_passenger_id then
    v_reviewee_id := v_driver_id;
  elsif v_user_id = v_driver_id then
    v_reviewee_id := v_passenger_id;
  else
    raise exception 'Only the passenger or assigned driver can rate this ride.';
  end if;

  insert into public.ride_ratings (
    ride_id, reviewer_id, reviewee_id, rating, feedback
  )
  values (
    p_ride_id, v_user_id, v_reviewee_id, p_rating, v_feedback
  )
  returning id into v_rating_id;

  return v_rating_id;
end;
$$;

revoke all on function public.rryd_submit_ride_rating(bigint, smallint, text)
  from public, anon;
grant execute on function public.rryd_submit_ride_rating(bigint, smallint, text)
  to authenticated;

comment on table public.ride_ratings is
  'One immutable passenger-to-driver or driver-to-passenger rating per completed ride.';
