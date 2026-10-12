# Cosmo's Card Hop – setup

Files: `index.html` (the whole game), `supabase.sql` (leaderboard database).

## 1. Leaderboard (Supabase, ~5 minutes)
1. In Supabase, create a project.
2. Open **SQL Editor → New query**, paste all of `supabase.sql`, click **Run**.
3. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
   (The anon key is meant to be public. The SQL locks the table so people can only read scores
   and submit them through a checked function. Never put the `service_role` key in the game.)
4. (Already done for your project "Cosmos Card Hop's Project".) In `index.html`, near the top, this line holds the settings:
   `window.COSMO_LB={url:'https://xxxx.supabase.co',key:'eyJ...'};`

## 2. Publish (pick one)
**GitHub Pages:** new repo -> upload `index.html` -> Settings -> Pages -> deploy from `main` / root.
**GitLab Pages:** new project -> add `index.html` and a `.gitlab-ci.yml`:

    pages:
      stage: deploy
      script:
        - mkdir public
        - cp index.html public/
      artifacts:
        paths: [public]
      rules:
        - if: $CI_COMMIT_BRANCH == "main"

## 3. Check it works
Play, lose, type a name, press **Post score**. Rows appear in Supabase under **Table Editor → scores**.
Delete any test rows there. Scores under 3 seconds of play are rejected on purpose.

## Discord Activity
The page detects when Discord opens it (Discord adds `?frame_id=`) and then talks to Discord and routes
leaderboard calls through `/.proxy/supabase`. In the Discord Developer Portal -> your app -> Activities:
- Enable Activities, then under **URL Mappings** add:
  - `/`         -> the host that serves this page (e.g. `cwdiskin-hue.github.io/Cosmo-s-Card-Hop`)
  - `/supabase` -> `inytasopnpshomgmdcbl.supabase.co`
- Launch from a voice channel with the rocket (Activities) icon.
Application ID used by the page: 1559250192220426452
