# apt-tap

Shared apt (Debian/Ubuntu) package repository for [scootship](https://github.com/scootship)
org tools, published via GitHub Pages. One suite, many packages — the same
shared-repository model as [homebrew-tap](https://github.com/scootship/homebrew-tap)
(which hosts formulae for several unrelated tools in one repo), just for `.deb`
packages instead of Homebrew formulae.

## Install

```sh
curl -fsSL https://scootship.github.io/apt-tap/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/scootship-apt-tap.gpg
echo "deb [signed-by=/usr/share/keyrings/scootship-apt-tap.gpg] https://scootship.github.io/apt-tap stable main" | sudo tee /etc/apt/sources.list.d/scootship-apt-tap.list
sudo apt update
```

Then install any package published here, e.g.:

```sh
sudo apt install scootship
```

## Packages

| Package | Source project |
| --- | --- |
| `scoot` | [scootship/scoot](https://github.com/scootship/scoot) — lightweight, local-first, auditable AI agent daemon and CLI |
| `scootship` | [scootship/scootship](https://github.com/scootship/scootship) — management center for a fleet of Scoot agents |

The table above is updated as each project starts publishing here; a package only shows
up in the actual repository once its own release workflow has pushed a `.deb` into
`pool/`.

## How this repository works

- `pool/` holds the actual `.deb` files, pushed here by each source project's own
  release workflow (standard apt `pool/<component>/<letter>/<source>/` layout, e.g.
  `pool/main/s/scootship/`).
- `dists/` (the apt index: `Release`, `InRelease`, `Packages`, `Packages.gz`) is
  **never committed to git**. It is fully regenerated from `pool/` on every push by
  [`.github/workflows/publish.yml`](.github/workflows/publish.yml) via
  [`scripts/build-repo.sh`](scripts/build-repo.sh), and published straight to GitHub
  Pages as a build artifact. This keeps git history free of generated-index merge
  conflicts even when multiple unrelated projects push new packages concurrently.
- A single suite (`stable`) and a single component (`main`) are shared by every package
  here, exactly like `homebrew-tap` shares one `Formula/` directory across multiple
  unrelated tools.
- Releases are signed with a repository-owned GPG key (`APT_TAP_GPG_PRIVATE_KEY`,
  stored only as a secret on this repository — no source project's own workflow ever
  touches it). The public key is published at
  [`pubkey.gpg`](https://scootship.github.io/apt-tap/pubkey.gpg) once a signing key has
  been configured. Until a signing key is configured, `publish.yml` publishes an
  **unsigned** repository (bootstrap/test mode only).

## Adding a new package from another project

1. Build your `.deb` in your own project's release workflow.
2. Push it into `pool/main/<first-letter-of-source-name>/<source-name>/` on the `main`
   branch of this repository. A PAT with push access to this repo, stored as a secret
   in your own project (e.g. `scootship/scootship` uses `SCOOTSHIP_RELEASE_TOKEN`), is all that's
   needed.
3. This repository's own workflow rebuilds and republishes `dists/` automatically on
   the next push to `pool/**`. Your project's workflow never needs the signing key.
