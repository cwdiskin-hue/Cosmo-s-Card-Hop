-- Cosmo's Card Hop leaderboard. Paste into Supabase: SQL Editor -> New query -> Run.

create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  name       text   not null check (char_length(name) between 1 and 14),
  score      int    not null check (score > 0),
  dist       int    not null,
  cards      int    not null,
  secs       int    not null,
  created_at timestamptz not null default now()
);

alter table public.scores enable row level security;

-- Anyone may READ scores. Nobody can insert/update/delete directly.
drop policy if exists "scores are public" on public.scores;
create policy "scores are public" on public.scores for select using (true);
revoke insert, update, delete on public.scores from anon, authenticated;

-- The only way to add a score: this function, which rejects impossible runs.
create or replace function public.submit_score(
  p_name text, p_score int, p_dist int, p_cards int, p_secs int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  n text := btrim(regexp_replace(coalesce(p_name,''), '\s+', ' ', 'g'));
begin
  if char_length(n) < 1 or char_length(n) > 14 then raise exception 'bad name'; end if;
  if p_score <= 0 or p_dist < 0 or p_cards < 0 or p_secs < 3 then raise exception 'bad run'; end if;
  -- score = distance*10 + cards*100..500 + 1000 per finished set of 5 colours
  if p_score > p_dist*10 + p_cards*500 + (p_cards/5 + 1)*1000 then raise exception 'score too high'; end if;
  if p_dist > p_secs*12 + 30 then raise exception 'too far too fast'; end if;
  if p_cards > p_dist*0.7 + 12 then raise exception 'too many cards'; end if;
  -- simple flood limit: max 1 post per name every 10 seconds
  if exists (select 1 from scores where lower(name)=lower(n) and created_at > now() - interval '10 seconds') then
    raise exception 'slow down';
  end if;
  insert into scores(name, score, dist, cards, secs) values (n, p_score, p_dist, p_cards, p_secs);
end $$;

grant execute on function public.submit_score(text,int,int,int,int) to anon, authenticated;
grant select on public.scores to anon, authenticated;
