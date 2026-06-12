# Bifrost

Bifrost is a small Bash utility for connecting to SSH targets from a named list.
It keeps server definitions in a local profile, supports aliases, can install itself as a standalone command, and can update from GitHub releases.

Current script version: `3.6.1`

## Features

- Interactive server picker with live reachability checks
- Direct connect by index, alias, exact name, or unique name prefix
- Local profile storage outside the repository
- Add and remove servers from the CLI
- Add and remove aliases from the CLI
- Quick version output from the CLI and interactive UI
- Self-install to a command path such as `/usr/bin/bifrost`
- Release-based update flow with checksum verification

## Requirements

- `bash`
- `ssh`
- One of `curl` or `wget` for update checks and downloads
- One of `sha256sum` or `shasum` for release verification

Optional utilities:

- `sudo` for installing into protected directories
- `nc` for port checks in the interactive status view
- `ping` as a fallback when `nc` is unavailable

## Files

- [bifrost.sh]: main script
- [profile.example.sh]: safe example profile

## Installation

Run the script directly:

```bash
bifrost.sh
```

Install it as `bifrost`:

```bash
bifrost.sh install
```

That installs the script to the current install path and creates a default profile if one does not exist.

## Configuration

By default, Bifrost loads its profile from:

```bash
$HOME/.config/bifrost/profile.sh
```

You can override that path with:

```bash
export BIFROST_PROFILE=/path/to/profile.sh
```

Profile format:

```bash
SERVER_ENTRIES=(
    "example-prod|203.0.113.10|admin|22"
    "example-dev|198.51.100.20|devuser|22"
)

ALIAS_ENTRIES=(
    "prod|example-prod"
    "dev|example-dev"
)
```

`SERVER_ENTRIES` use this format:

```text
name|host|user|port
```

`ALIAS_ENTRIES` use this format:

```text
alias|server-name
```

Keep real infrastructure values in your local profile, not in the script.

## Usage

```bash
bifrost                      # interactive menu
bifrost <target>             # connect by index, alias, name, or unique prefix
bifrost version
bifrost -v
bifrost add <name> <host> [user] [port]
bifrost remove <name|index>
bifrost alias add <alias> <server-name|index>
bifrost alias remove <alias>
bifrost list
bifrost check-update
bifrost install
bifrost update
bifrost help
```

### Target resolution

`bifrost <target>` accepts:

- Numeric index, such as `0`
- Alias, such as `prod`
- Exact server name
- Unique server name prefix

Inside the interactive menu:

- `h` or `help` shows a short help summary
- `v` or `version` prints the current Bifrost version
- `q` or `quit` exits the UI

## Management examples

Add a server:

```bash
bifrost add web01 203.0.113.25 deploy 22
```

Add a server interactively:

```bash
bifrost add
```

Remove a server by name or index:

```bash
bifrost remove web01
bifrost remove 0
```

Add and remove aliases:

```bash
bifrost alias add prod web01
bifrost alias remove prod
```

List configured entries:

```bash
bifrost list
```

## Updating

Check whether a newer GitHub release exists:

```bash
bifrost check-update
```

Download and install the latest release after checksum verification:

```bash
bifrost update
```

## Environment variables

- `BIFROST_PROFILE`: override the profile file path
- `BIFROST_INSTALL_DIR`: override the install directory
- `BIFROST_GITHUB_REPO`: override the GitHub repo used for release checks
- `BIFROST_GITHUB_TOKEN`: GitHub token for private repositories or higher API limits
- `GITHUB_TOKEN`: fallback token source
- `BIFROST_RELEASE_ASSET`: override the release asset name
- `BIFROST_CHECKSUM_ASSET`: override the checksum asset name

## Notes

- If no servers are configured, the interactive mode exits and tells you to add one first.
- Removing a server also removes aliases that point to it.
- Alias names are matched case-insensitively.