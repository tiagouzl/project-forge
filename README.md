# Project Forge

A lightweight project scaffolding CLI built entirely with Bash.

`forge` creates projects from templates, substitutes variables, validates
names/destinations, and optionally initializes a Git repository — with no
dependency on Python, Node, or any runtime beyond basic utilities
(`bash`, `cp`, `mkdir`, `find`, `sort`, `perl`, `git`).

## Install

```bash
git clone https://github.com/tiagouzl/project-forge.git
cd project-forge
./forge list
```

## Usage

```bash
./forge list

./forge new python little-tool
./forge new cpp sensor --dry-run
./forge new bash backup-tool --path ~/Projects --no-git
```

Aliases: `create` for `new`, `rm` for `template remove`.

## Options

| Flag            | Effect                                                              |
|-----------------|---------------------------------------------------------------------|
| `--path <dir>`  | Parent directory for the new project (default: `.`, or `default_path` from config) |
| `--no-git`      | Skip Git repository initialization                                  |
| `--force`       | Overwrite the destination if it already exists                      |
| `--dry-run`     | Show what would be created, without touching disk                   |

## Environment

```bash
./forge doctor
```

Checks the forge's **core** dependencies (`bash`, `perl`, `git` —
without them forge doesn't work) and the **optional toolchains** used by
generated projects (`python3`, `gcc`, `g++` — forge creates the files
anyway; building/running afterwards is each toolchain's job).

## Configuration

Optional, at `${XDG_CONFIG_HOME:-~/.config}/project-forge/config`
(`KEY=VALUE` format, one per line; `#` starts a comment):

```bash
default_path=~/Projects
no_git=false
```

- `default_path` — default parent directory for `forge new` (default: `.`).
- `no_git` — `true`/`false` (default: `false`). With `true`, `new` skips
  `git init` — and there is no flag to re-enable it per command; remove it
  from the config.
- Unknown keys are ignored; invalid `no_git` is ignored with a warning.
- CLI flags win over config (`--path` overrides `default_path`,
  `--no-git` forces no git). Missing file = current behavior.

## Custom templates

Beyond the three built-in templates, you can add your own, stored in
`${XDG_CONFIG_HOME:-~/.config}/project-forge/templates/` (outside the
forge repository):

```bash
./forge template add node ./my-local-template
./forge template add node https://github.com/user/my-template.git

./forge template list
./forge template remove node
./forge template remove node --force   # no interactive confirmation
```

Rules:
- A **built-in template name can never be overridden** (`python`, `cpp`, `bash`).
- Local directory sources are copied as-is; git sources are cloned
  (`--depth 1`) and the resulting `.git` is removed — the template keeps
  only the files.
- Sources containing symlinks (local or cloned) are refused.
- `./forge list` shows built-in and custom templates together, marking
  custom ones with `(custom)`.

## Templates

| Name     | Contents                                                |
|----------|---------------------------------------------------------|
| `python` | package in `src/<slug>/`, tests, `.gitignore`, `run.sh` |
| `cpp`    | `src/main.cpp`, `include/`, `tests/`                    |
| `bash`   | executable script in `src/`, basic test                 |

Templates use two placeholders:
- `{{PROJECT_NAME}}` / `{{PROJECT_SLUG}}` — substituted in file *contents*.
- `__PROJECT_SLUG__` — substituted in file/directory *names*.

## Tests

```bash
bats tests/forge.bats
```

Requires [bats-core](https://github.com/bats-core/bats-core) (`npx bats` also works).

## Roadmap

- **v0.1**: `new`, `list`, Python/C++/Bash templates, validation, `--dry-run`, Git.
- **v0.2**: `forge doctor` (environment detection: bash, perl, git, python, gcc).
- **v0.3**: external templates (`forge template add/list/remove`).
- **v0.4** (current): user configuration in `~/.config/project-forge/config` (`default_path`, `no_git`).

## License

MIT — see [LICENSE](LICENSE).
