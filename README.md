# coraza-spoa-crs packaging

This repository builds Debian and RPM packages for the [coraza-spoa](https://github.com/corazawaf/coraza-spoa) daemon bundled with the [OWASP Core Rule Set](https://github.com/coreruleset/coreruleset). The resulting package is named `coraza-spoa-crs` and is intended to be installed alongside HAProxy.

## Structure

- `scripts/prepare-rootfs.sh` downloads and builds `coraza-spoa`, fetches the CRS assets, and assembles a root filesystem under `build/`.
- `packaging/nfpm/*.sh` contains the lifecycle scripts used by nfpm.
- `config/`, `haproxy/`, `systemd/`, and `logrotate/` provide the configuration files installed by the package.
- `.goreleaser.yml` drives snapshot and release builds (packages only).
- `versions.env` pins upstream versions and packaging metadata.

## Prerequisites

The build scripts expect:

- Go 1.25 or newer on the PATH (used to compile `coraza-spoa`).
- `git`, `curl`, `find`, and standard GNU utilities.
- Network access to GitHub to download sources.

## Version pinning

`versions.env` exports the upstream references and packaging release identifier:

- `CORAZA_SPOA_VERSION` **must** match the upstream tag and will also be the git tag used for releasing this repository.
- `CRS_REF` is the git ref used when cloning the Core Rule Set.
- `CRS_VERSION` is a normalized string (e.g., `4.0.0` or `4.0.0+patch1`) that is used when naming release artifacts or changelog entries.
- `PACKAGE_RELEASE` controls the nfpm `release` field so you can push `-1`, `-2`, … when only the CRS content changes.

Update these values in a commit before cutting a release, or override them per build with environment variables.

## Building locally

```bash
# Populate build/rootfs/ and build/prebuilt/
make build

# Produce snapshot packages under dist/ (requires goreleaser)
make snapshot
```

`make build` is idempotent and can be re-run to refresh the root filesystem. `make snapshot` runs `goreleaser release --snapshot`, so you can inspect the generated `.deb` and `.rpm` artifacts in `dist/`.

## Releasing

1. Update `versions.env` to the desired upstream versions and bump `PACKAGE_RELEASE` if only the CRS content changed.
2. Commit the changes and push them to the default branch.
3. Trigger the `Release` workflow manually in GitHub with:
   - `version`: the packaging tag using the pattern `v<coraza-version>-<release>` (e.g., `v0.4.0-1`). The workflow derives the upstream coraza tag from the part before the first `-`.
   - `package_release`: the same release counter (defaults to `1`).

The workflow validates the version string, runs the preparation build, creates packages via GoReleaser, tags the repository, and publishes a GitHub release. Generated artifacts are named `coraza-spoa-crs_<version>-<release>_<arch>.{deb,rpm}`.

To cut a packaging-only update (e.g., bumping CRS rules) reuse the same upstream version and bump only the release counter: tag the repo with `v0.4.0-2`, set `package_release` to `2`, and update `PACKAGE_RELEASE` in `versions.env` if you run the build locally.

## Installing the package

The package creates a `coraza-spoa` system user, installs the bundled CRS assets into `/etc/coraza-spoa`, and enables the `coraza-spoa.service` systemd unit. Configuration files are marked as `config|noreplace`, so local modifications are preserved on upgrades. The service depends on HAProxy and listens on `127.0.0.1:9000` by default. Adjust `/etc/default/coraza-spoa` to pass additional flags if needed.

## Updating CRS content without a new coraza-spoa release

When only the CRS assets change, keep `CORAZA_SPOA_VERSION` untouched, adjust `CRS_REF`/`CRS_VERSION` as needed, bump `PACKAGE_RELEASE`, and cut a new release. The resulting packages retain the same upstream version with an incremented distro release suffix.

## License

Distributed under the GNU Affero General Public License v3.0. See `LICENSE` for details.
