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
3. Obtain the server's SSH host key through a trusted channel. Add its
   `known_hosts` line to the GitHub environment secret `PROD_SSH_KNOWN_HOSTS`.
   Compare its fingerprint with the server's host key before saving it; do not
   trust a fresh `ssh-keyscan` result by itself.
4. In **Settings → Environments**, create `production`, restrict it to `main`,
   and configure required reviewers if available for the repository. Add these
   environment variables:

   | Variable | Value |
   | --- | --- |
   | `PROD_HOST` | Server's SSH hostname or IP |
   | `PROD_USER` | Dedicated deploy user's login |
   | `PROD_DIR` | Absolute path to the server's repository checkout |

5. Run the workflow manually from `main`. Check the Actions log and the live
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
