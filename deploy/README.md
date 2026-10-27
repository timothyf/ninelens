# Production deployment workflow

The GitHub Actions workflow in `.github/workflows/deploy-production.yml` runs
the same deployment sequence currently used on the server. It starts manually
from the **Actions → Deploy production → Run workflow** menu on `main`. The
workflow runs the frontend unit tests and build, waits for the `production`
environment's approval rules, connects to the server, deploys the exact commit
that was tested, and checks `https://www.ninelens.com/up` and the homepage.

## One-time setup

1. Keep the server's repository checkout on `main`, with a clean tracked working
   tree and its existing `.env` file in the repository root. The deploy user
   needs permission to run Docker Compose and to pull the repository. Keep
   `.env` on the server; do not add it to GitHub Actions secrets.
2. Create a dedicated SSH key for GitHub Actions, add its public key to the
   deploy user's `~/.ssh/authorized_keys` on the server, and put its private key
   in the GitHub environment secret `PROD_SSH_KEY`. Limit this account's access
   to what deployment requires.
3. Connect the production server to Tailscale with the `tag:prod-server` tag.
   In the tailnet access policy, allow `tag:ci` to reach `tag:prod-server` on
   `tcp:22`. Remove any broad default grant that would also give `tag:ci`
   wider access, while preserving other access your tailnet needs. Create a
   Tailscale OAuth client with the writable Auth Keys scope and `tag:ci`.
   Put its client ID and secret in the GitHub `production` environment secrets
   `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET`. The deploy job joins the tailnet
   as an ephemeral `tag:ci` device before SSHing to the server.
4. Obtain the server's SSH host key through a trusted channel. Add a
   `known_hosts` line for the server's Tailscale IPv4 address to the GitHub
   environment secret `PROD_SSH_KNOWN_HOSTS`. Compare its fingerprint with the
   server's host key before saving it; do not trust a fresh `ssh-keyscan`
   result by itself. The existing SSH key remains `PROD_SSH_KEY`.
5. In **Settings → Environments**, create `production`, restrict it to `main`,
   and configure required reviewers if available for the repository. Add these
   environment variables:

   | Variable | Value |
   | --- | --- |
   | `PROD_HOST` | Server's Tailscale IPv4 address (`tailscale ip -4` on the server) |
   | `PROD_USER` | Dedicated deploy user's login |
   | `PROD_DIR` | Absolute path to the server's repository checkout |

6. Run the workflow manually from `main`. Check the Actions log and the live
   site. The job fails before building if the server checkout is dirty, is not
   on `main`, or pulls a different commit from the one the workflow tested.

Once manual deployments work, add a `push` trigger for `main` to the workflow if
every merge should request a production deployment. Keep the `production`
environment approval rule if each deployment should require review.

The server command uses both Compose files:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.production.yml
```

The checked-in README's older command uses only the production override and
does not validate by itself. The production override reads `DOMAIN` while the
environment example sets `APP_DOMAIN`; its backend database name also differs
from the database configured by the base Compose file. The workflow preserves
the currently working server sequence; reconcile those configuration files
against the live server before changing them.

## View production container logs

The production Compose override runs Dozzle on the server's loopback interface
at port 9999. To open it from your computer, create an SSH tunnel to the server
and visit `http://localhost:9999`:

```bash
ssh -L 9999:localhost:9999 <prod-user>@<prod-host>
```

Use the same SSH access you use for server administration; `<prod-host>` can be
the server's Tailscale address. Dozzle can see logs from all containers on the
Docker host. Keep its port private because access to the mounted Docker
socket grants powerful control over the host. Dozzle shows logs retained by
Docker, so configure Docker log rotation and retention separately.
