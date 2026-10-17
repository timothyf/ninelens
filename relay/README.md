# NineLens MLB relay

This Netlify Function provides a private egress path from NineLens to the MLB Stats API. It is not a general-purpose proxy: it accepts only authenticated `GET` requests, fixes the upstream host to `statsapi.mlb.com`, and allowlists the MLB paths NineLens uses.

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

Run `npm test` from this directory to test authentication, path validation, and upstream forwarding locally.
