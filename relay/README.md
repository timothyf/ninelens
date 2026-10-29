# NineLens data relays

This Netlify Function provides a private egress path from NineLens to the MLB Stats API. It is not a general-purpose proxy: it accepts only authenticated `GET` requests, fixes the upstream host to `statsapi.mlb.com`, and allowlists the MLB paths NineLens uses.

The `fangraphs-relay` function uses the same shared secret and forwards only `GET` requests to the FanGraphs major-league leaders API. Player season batting, pitching, and fielding leaderboard requests use it. RosterResource payroll page requests remain direct.

## Deploy

1. Generate one shared secret:

   ```bash
   openssl rand -hex 32
   ```

2. Create a Netlify site from this repository. The root `netlify.toml` sets `relay/` as the site base.

3. In Netlify, create `MLB_RELAY_TOKEN` with the generated value and make its scope include Functions. Redeploy after setting or changing it.

4. Verify authentication against the deployed function:

   ```bash
   curl -i \
     -H "X-NineLens-Relay-Token: YOUR_SHARED_SECRET" \
     'https://YOUR-SITE.netlify.app/.netlify/functions/mlb-relay?upstream=%2Fapi%2Fv1%2Fschedule%3FsportId%3D1'
   ```

5. Add these values to the NineLens production environment:

   ```dotenv
   MLB_STATS_API_RELAY_URL=https://YOUR-SITE.netlify.app/.netlify/functions/mlb-relay
   MLB_STATS_API_RELAY_TOKEN=YOUR_SHARED_SECRET
   ```

6. Rebuild and recreate the NineLens backend container. The frontend does not receive either secret.

When `MLB_STATS_API_RELAY_URL` ends in `/mlb-relay`, the backend automatically sends FanGraphs leaderboard requests to the sibling `/fangraphs-relay` endpoint using `MLB_STATS_API_RELAY_TOKEN`. For a different deployment layout, set `FANGRAPHS_API_RELAY_URL` to the full HTTPS function URL and optionally set `FANGRAPHS_API_RELAY_TOKEN` if it uses a different secret.

Run `npm test` from this directory to test authentication, path validation, and upstream forwarding locally.
