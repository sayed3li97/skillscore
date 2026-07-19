# skillscore (npm)

Lint and score AI agent skills (`SKILL.md`) against the official Claude, Codex,
and Antigravity authoring guides. Offline, deterministic, no API key.

This npm package is a thin launcher for the native `skillscore` CLI, so you can
run it with **no Dart toolchain**:

```bash
# Run it once, no install
npx skillscore path/to/skills/

# Or install it
npm install -g skillscore
skillscore path/to/skills/ --min-score 80
```

## How it works

The CLI itself is a native binary compiled from Dart. One binary per platform is
published as an optional package (`@skillscore/cli-<platform>-<arch>`), and npm
installs only the one matching your machine. The `skillscore` command is a small
Node shim that execs that binary and forwards your arguments and exit code, so it
behaves exactly like the natively installed tool.

Supported platforms: `darwin-x64`, `darwin-arm64`, `linux-x64`, `linux-arm64`,
`win32-x64`. On any other platform, install via Dart instead:
`dart pub global activate skillscore`.

## Usage

```bash
skillscore <path> [<path> ...]     # score manifests, folders, or trees
skillscore rules                   # list every rule
skillscore explain <rule-id>       # a rule's rationale, fix, and source
skillscore conflicts <path> ...    # find skills that trigger on the same requests
skillscore budget <path> ...       # measure the always-on token cost of a skill set
skillscore --help
```

Full documentation, the rubric, editor integration, and the CI/CD kit:
<https://github.com/sayed3li97/skillscore#readme>.

## License

Apache-2.0
