-- Account deletion support — App Store Review Guideline 5.1.1(v)
--
-- Run this before deploying the delete-account Edge Function.
--
-- Two parts:
--   1. ON DELETE CASCADE from every per-user table to auth.users, so deleting
--      the auth record takes the application data with it. This turns "delete
--      twelve tables in the right order without missing one" into one
--      statement, and keeps working when a thirteenth table is added.
--   2. apple_tokens, which holds the Apple refresh token that deletion revokes.
--      Service-role only — no client ever reads or writes it.

begin;

-- ---------------------------------------------------------------- 1. cascades
--
-- NOT every table keys on user_id. `profiles` keys on `id`, following the
-- standard Supabase pattern where the profile row shares the auth user's id —
-- which is also how the app queries it (SupabaseSyncManager: .eq("id", userId)).
-- An earlier version of this migration assumed user_id everywhere and failed on
-- the first table.
--
-- The owner column is therefore explicit per table. A table whose column is
-- missing is skipped with a notice rather than aborting the whole migration, so
-- schema drift shows up as a warning instead of a half-applied push.

do $$
declare
  rec   record;
  cname text;
  pairs constant text[][] := array[
    ['profiles',              'id'],
    ['reading_sessions',      'user_id'],
    ['session_letter_stats',  'user_id'],
    ['letter_stats',          'user_id'],
    ['troubled_words',        'user_id'],
    ['daily_tasks',           'user_id'],
    ['exercise_logs',         'user_id'],
    ['conversation_sessions', 'user_id'],
    ['journeys',              'user_id'],
    ['streaks',               'user_id'],
    ['user_awards',           'user_id'],
    ['user_goals',            'user_id']
  ];
  i int;
  tbl text;
  col text;
begin
  for i in 1 .. array_length(pairs, 1) loop
    tbl := pairs[i][1];
    col := pairs[i][2];

    if to_regclass('public.' || quote_ident(tbl)) is null then
      raise notice 'skipping %: table not found', tbl;
      continue;
    end if;

    if not exists (
      select 1 from pg_attribute
      where attrelid = ('public.' || quote_ident(tbl))::regclass
        and attname = col
        and not attisdropped
        and attnum > 0
    ) then
      raise notice 'skipping %: column % not found', tbl, col;
      continue;
    end if;

    -- Drop whatever foreign key currently sits on that column, whatever it is
    -- called, so this migration is safe to re-run.
    for rec in
      select c.conname
      from pg_constraint c
      where c.contype = 'f'
        and c.conrelid = ('public.' || quote_ident(tbl))::regclass
        and c.conkey = array[(
          select a.attnum from pg_attribute a
          where a.attrelid = c.conrelid and a.attname = col
        )]::smallint[]
    loop
      execute format('alter table public.%I drop constraint %I', tbl, rec.conname);
      raise notice 'dropped % on %', rec.conname, tbl;
    end loop;

    cname := tbl || '_' || col || '_fkey';
    execute format(
      'alter table public.%I add constraint %I
         foreign key (%I) references auth.users(id) on delete cascade',
      tbl, cname, col
    );
    raise notice 'cascade added: %.% -> auth.users(id)', tbl, col;
  end loop;
end $$;

-- ----------------------------------------------------------- 2. apple_tokens
--
-- Apple requires that deleting an account created with Sign in with Apple also
-- revokes the token grant. Revocation needs a refresh token, which is obtained
-- once by exchanging the authorization code Apple returns at sign-in. The code
-- is single-use and expires in about five minutes, so it is exchanged
-- immediately and the resulting refresh token parked here.

create table if not exists public.apple_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.apple_tokens enable row level security;

-- Deliberately no policies. RLS with zero policies denies every client,
-- including the publishable key. Only the service role, which bypasses RLS,
-- can touch this table — and only from inside an Edge Function.
--
-- Do not add a policy here "so the app can read its own token". The app has no
-- reason to see it, and a refresh token in the client is a credential leak.

comment on table public.apple_tokens is
  'Apple refresh tokens for Sign in with Apple revocation on account deletion. Service-role only; RLS enabled with no policies by design.';

commit;
