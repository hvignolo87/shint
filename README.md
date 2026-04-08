# shint

**Shell hints** — fzf-powered autocomplete with descriptions for bash.

Press Tab, get an interactive fuzzy picker with documentation for every flag, subcommand, and argument. Works with 5,900+ commands out of the box.

```
$ dbt run --[Tab]

  --defer          Defer to the state variable for resolving unselected nodes
  --exclude        Specify the models to exclude
  --fail-fast      Stop execution upon a first failure
  --full-refresh   Drop incremental models and fully-recalculate
  --models         Specify the nodes to include
  --select         Specify the nodes to include
  --state          Use the given directory as the source for json files to compare
  --target         Which target to load for the given profile
  --threads        Specify number of threads to use while executing models

  9/21 flags
```

## The problem

Bash's built-in autocomplete shows plain text with no descriptions. You know a flag exists but can't remember its exact name, or what `--defer` vs `--state` does, or which branches are available. You end up running `--help` and reading walls of text.

## The solution

**shint** replaces bash's Tab completion with an interactive [fzf](https://github.com/junegunn/fzf) picker that shows descriptions alongside every suggestion. It uses [carapace](https://github.com/carapace-sh/carapace-bin) as its data engine, which provides completion specs for 5,900+ commands — including dynamic values like git branches, docker containers, and tox environments.

The entire tool is ~130 lines of bash.

## Features

- **Descriptions for everything** — flags, subcommands, arguments all show inline documentation
- **5,900+ commands** supported via carapace (git, docker, kubectl, dbt, npm, curl, ssh, brew, and thousands more)
- **Dynamic values** — git branches (with commit messages), docker containers, tox envs, npm scripts, ssh hosts
- **Fuzzy search** — type any part of a flag name to filter instantly
- **Smart level advancement** — type `dbt run` and Tab shows flags, not subcommand matches
- **Subcommands + flags merged** — see both available subcommands and global flags in one list
- **Single-result auto-insert** — if there's only one match, it completes directly without opening the picker
- **Zero config** — works immediately after installation
- **~130 lines of bash** — no Python, no Node, no compilation

## Requirements

| Dependency | Version | Install |
| --- | --- | --- |
| **bash** | 4.0+ | `brew install bash` (macOS ships 3.2) |
| **[carapace-bin](https://github.com/carapace-sh/carapace-bin)** | any | `brew install carapace` |
| **[fzf](https://github.com/junegunn/fzf)** | any | `brew install fzf` |

### macOS note on bash version

macOS ships bash 3.2 (from 2007) at `/bin/bash`. shint requires bash 4.0+ for `READLINE_LINE` support. After installing modern bash via Homebrew, switch your login shell:

```bash
# Add Homebrew bash to allowed shells
sudo sh -c 'grep -qxF /opt/homebrew/bin/bash /etc/shells || echo /opt/homebrew/bin/bash >> /etc/shells'

# Switch your login shell
chsh -s /opt/homebrew/bin/bash

# Restart your terminal, then verify
echo $BASH_VERSION  # Should show 5.x
```

## Installation

### Quick install

```bash
# 1. Install dependencies
brew install carapace fzf bash

# 2. Clone shint
git clone https://github.com/hvignolo87/shint.git ~/.shint

# 3. Run the installer (adds source line to .bashrc)
~/.shint/install.sh

# 4. Restart your terminal or:
source ~/.bashrc
```

### Manual install

Clone the repo and add this line to your `~/.bashrc`:

```bash
# shint
source "$HOME/.shint/shint.bash"
```

## Usage

Just press **Tab** as you normally would. shint intercepts Tab for all commands that carapace supports and falls through for everything else.

### Examples

**See subcommands with descriptions:**

```
$ git [Tab]         → shows all git subcommands with descriptions
$ kubectl [Tab]     → shows kubectl subcommands
$ dbt [Tab]         → shows dbt subcommands (run, test, build, seed...)
```

**See flags with documentation:**

```
$ git push --[Tab]  → shows --force, --set-upstream, --dry-run, etc.
$ dbt run --[Tab]   → shows --defer, --select, --full-refresh, etc.
$ curl --[Tab]      → shows all 200+ curl flags with descriptions
```

**Complete dynamic values:**

```
$ git checkout [Tab]  → shows branches with last commit message
$ git push -u [Tab]   → shows remotes
$ docker exec [Tab]   → shows running containers
$ tox -e [Tab]        → shows available tox environments
$ ssh [Tab]           → shows hosts from ~/.ssh/config
```

**Smart level advancement:**

```
$ dbt run[Tab]   → shows flags for "dbt run" (not subcommand matches)
$ git push[Tab]  → shows flags for "git push"
```

**Single match auto-completes:**

```
$ git pus[Tab]   → completes directly to "git push " (no picker)
```

**Fuzzy search in the picker:**

```
$ dbt run --[Tab]  → picker opens → type "sel" → filters to --select, --selector
```

Press **Esc** to cancel without changing anything.

## Configuration

Set these environment variables **before** sourcing shint:

```bash
# fzf picker height (default: ~40%)
export SHINT_HEIGHT="~50%"

# Extra fzf options (appended to the fzf call)
export SHINT_FZF_OPTS="--color=bg+:#363a4f"

# shint
source "$HOME/.shint/shint.bash"
```

## How it works

shint is a thin bridge between three components:

```
Tab press
    │
    ▼
┌──────────────────────────────┐
│  bash (bind -x)              │
│  Captures READLINE_LINE      │
│  Tokenizes the command line  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  carapace (data engine)      │
│  5,900+ command specs        │
│  Dynamic value resolution    │
│  Returns: value\tdescription │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  fzf (interactive picker)    │
│  Fuzzy search on values      │
│  Descriptions shown inline   │
│  Returns: selected value     │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  bash                        │
│  Inserts value into          │
│  READLINE_LINE               │
└──────────────────────────────┘
```

### Key implementation details

- **Tab binding**: Uses a readline macro redirect (`\C-i` → `\200` → `bind -x`) to avoid conflicts with bash's built-in completion system.
- **Carapace fish format**: Calls `carapace <cmd> fish <tokens>` which outputs tab-separated `value\tdescription` pairs — trivially parseable and ideal for fzf.
- **Flag merging**: When completing a new argument, shint fetches both positional completions and available flags, merging them into a single list.
- **Level advancement**: If the current token exactly matches a known subcommand, shint automatically advances to show the next level (flags/arguments) instead of offering to complete the already-typed subcommand.

## Acknowledgments

shint is a ~130-line bash script that stands on the shoulders of two excellent projects:

- **[carapace-bin](https://github.com/carapace-sh/carapace-bin)** by [@rsteube](https://github.com/rsteube) — the completion engine with 5,900+ command specs. shint would not exist without it.
- **[fzf](https://github.com/junegunn/fzf)** by [@junegunn](https://github.com/junegunn) — the interactive fuzzy finder that powers the picker UI.

## License

[MIT](LICENSE)
