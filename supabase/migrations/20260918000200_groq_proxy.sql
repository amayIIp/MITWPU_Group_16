-- Rate limiting for the groq-chat Edge Function.
--
-- Context: the Groq API key used to be compiled into the app binary, where
-- anyone could recover it from the IPA and spend against the account. It now
-- lives only as an Edge Function secret.
--
-- The function is authenticated-only (decision D6), so every caller is a real
-- user and buckets are keyed by user id. This table bounds what a single
-- compromised account can spend, and the limits can be changed server-side
-- without shipping an app update.

begin;

create table if not exists public.ai_usage (
  bucket      text primary key,          -- 'user:<uuid>'
  window_start timestamptz not null default now(),
  request_count integer not null default 0
);

alter table public.ai_usage enable row level security;
-- No policies: service-role only, same reasoning as apple_tokens.

comment on table public.ai_usage is
  'Rate-limit counters for the groq-chat Edge Function. Service-role only; RLS enabled with no policies by design.';

-- Atomic increment-and-check. Returns true when the request is allowed.
-- Doing this in one statement avoids the read-then-write race that would let
-- concurrent requests both pass the check.
create or replace function public.ai_usage_allow(
  p_bucket text,
  p_limit integer,
  p_window interval
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.ai_usage (bucket, window_start, request_count)
  values (p_bucket, now(), 1)
  on conflict (bucket) do update
    set request_count = case
          when public.ai_usage.window_start < now() - p_window then 1
          else public.ai_usage.request_count + 1
        end,
        window_start = case
          when public.ai_usage.window_start < now() - p_window then now()
          else public.ai_usage.window_start
        end
  returning request_count into v_count;

  return v_count <= p_limit;
end $$;

revoke all on function public.ai_usage_allow(text, integer, interval) from public, anon, authenticated;

commit;
