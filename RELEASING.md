# NineLens release process

NineLens uses the root [`VERSION`](VERSION) file as the canonical application version. The frontend package metadata is kept in sync with it for build and artifact identification.

Version 1.0.0 is a source release. Production deployment, hosting configuration, and live operational validation are intentionally deferred to a future release.

## Prepare a release

1. Confirm the working tree is clean and review the changes since the last release.
2. Update `VERSION` to the release version using semantic versioning.
3. Move the completed entries from `CHANGELOG.md` into a dated release section and leave a new `Unreleased` section at the top.
4. Update `frontend/package.json` and the root package entry in `frontend/package-lock.json` to the same version.
5. Run the release checks:

   ```sh
   cd backend
   bundle exec rspec

   cd ../frontend
   npm ci
   npm run test:run
   npm run build
   npm run test:e2e
   ```

6. Verify the release scope: migrations are present and consistent, local setup documentation is current, test data isolation is working, and the automated checks pass. Production configuration, backups, scheduled synchronization, data-health verification, and deployment smoke tests are deferred.
7. Commit the release changes. A signed release commit is recommended:

   ```sh
   git add VERSION CHANGELOG.md RELEASING.md README.md frontend/package.json frontend/package-lock.json
   git commit -S -m "Release NineLens 1.0.0"
   ```

## Create and publish the release tag

Run these commands only after the release checks pass. Replace `1.0.0` with the version in `VERSION` when preparing a later release.

```sh
VERSION_NUMBER="$(tr -d '[:space:]' < VERSION)"
git tag -s "v${VERSION_NUMBER}" -m "NineLens ${VERSION_NUMBER}"
git tag -v "v${VERSION_NUMBER}"
git push origin main
git push origin "v${VERSION_NUMBER}"
```

The signing key must be configured in Git before tagging. Confirm the tag is annotated and signed with `git show --show-signature --stat v1.0.0`. If signing is not configured, stop and configure a GPG or SSH signing key; do not silently fall back to an unsigned release tag.

After publishing, create the source-code release from the tag and copy the corresponding `CHANGELOG.md` section into its release notes. Do not treat this source release as a production deployment. Keep the tag immutable; fixes should be released as a new patch version.

## Deferred deployment checklist

Complete these items when production deployment is introduced in a future release:

- Verify the deployed `/up` health endpoint.
- Verify login, public dashboards, saved analyses, watchlists, and administrator access.
- Verify at least one background task completes successfully.
- Record the deployed release version in the hosting/deployment metadata, if the host supports it.
- Record the deployment URL, tag, migration status, data snapshot, and rollback procedure.
