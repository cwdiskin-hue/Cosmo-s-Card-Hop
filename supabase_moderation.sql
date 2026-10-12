-- Name moderation for the Cosmo's Card Hop leaderboard.
-- Paste into Supabase: SQL Editor -> New query -> Run.  Safe to run more than once.

-- 1) Words that are not allowed in names. whole=false blocks the text anywhere in the name,
--    whole=true blocks it only as its own word (avoids false hits like "Dickson" or "Cassidy").
--    Add or remove rows any time in Table Editor -> blocked_words.
create table if not exists public.blocked_words (
  word  text primary key,
  whole boolean not null default false
);
alter table public.blocked_words enable row level security;   -- no policies = players can't read it

insert into public.blocked_words (word, whole) values
  ('fuck',false),('shit',false),('bitch',false),('nigg',false),('fagg',false),
  ('retard',false),('whore',false),('slut',false),('rapist',false),('nazi',false),('hitler',false),
  ('kike',true),('cunt',true),('spic',true),('chink',true),('coon',true),('tranny',true),('fag',true),
  ('dick',true),('cock',true),('pussy',true),('anus',true),('rape',true),('porn',true),('cum',true)
on conflict (word) do nothing;

-- 2) A "hidden" switch so you can remove a score without deleting it.
--    In Table Editor -> scores, tick `hidden` on any entry you don't want shown.
alter table public.scores add column if not exists hidden boolean not null default false;
drop policy if exists "scores are public" on public.scores;
create policy "scores are public" on public.scores for select using (not hidden);

-- 3) The submit function now checks the name.
create or replace function public.submit_score(
  p_name text, p_score int, p_dist int, p_cards int, p_secs int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  n    text := btrim(regexp_replace(coalesce(p_name,''), '\s+', ' ', 'g'));
  lc   text;
  flat text;
  w    record;
begin
  if char_length(n) < 1 or char_length(n) > 14 then raise exception 'bad name'; end if;

  -- undo common look-alike swaps (0->o, 1->i, 3->e, 4->a, 5->s, 7->t, @->a, $->s, !->i)
  lc   := translate(lower(n), '0134578@$!', 'oieasbtasi');
  flat := regexp_replace(lc, '[^a-z]', '', 'g');             -- letters only, spaces/dots removed

  if n ~* '(https?:|www\.|\.com|\.net|\.gg|\.org|discord)' or n ~ '@' or n ~ '[0-9]{6,}' then
    raise exception 'name not allowed';
  end if;
  for w in select word, whole from blocked_words loop
    if (w.whole = false and flat like '%' || w.word || '%')
       or (w.whole = true and regexp_replace(lc, '[^a-z ]', '', 'g') ~ ('\m' || w.word || '\M')) then
      raise exception 'name not allowed';
    end if;
  end loop;

  if p_score <= 0 or p_dist < 0 or p_cards < 0 or p_secs < 3 then raise exception 'bad run'; end if;
  if p_score > p_dist*10 + p_cards*500 + (p_cards/5 + 1)*1000 then raise exception 'score too high'; end if;
  if p_dist > p_secs*12 + 30 then raise exception 'too far too fast'; end if;
  if p_cards > p_dist*0.7 + 12 then raise exception 'too many cards'; end if;
  if exists (select 1 from scores where lower(name)=lower(n) and created_at > now() - interval '10 seconds') then
    raise exception 'slow down';
  end if;
  insert into scores(name, score, dist, cards, secs) values (n, p_score, p_dist, p_cards, p_secs);
end $$;

revoke all on function public.submit_score(text,int,int,int,int) from public;
grant execute on function public.submit_score(text,int,int,int,int) to anon, authenticated;
