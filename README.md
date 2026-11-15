# devops

Reusable CI/CD building blocks for Flutter + Supabase projects on GitHub Actions.

**What it is for.** Each project used to carry its own copy of the same workflows (quality checks, APK build,
releases, Supabase deployment, SQL tests). Here they are written once as *reusable workflows* and *composite
actions*; a project keeps only a few lines per workflow that call them, and fixes land everywhere at once.

Related repositories:
- [`dadamagouil/libs`](https://github.com/dadamagouil/libs): shared application code, SQL and Edge Function helpers.
- [`dadamagouil/models`](https://github.com/dadamagouil/models): file models (README, `DEPLOY.md`, `CLAUDE.md`, lint rules, Dependabot, PR/issue templates).

## Structure: one prefix or folder per technology

GitHub only reads workflows from a flat `.github/workflows/` folder and actions from `.github/actions/<name>/`,
so the technology is the **file-name prefix** there. Everything else has one folder per technology.

| Technology | Prefix / folder | Content today |
|---|---|---|
| Any (generic) | no prefix | `quality.yml`, `tag-release.yml`, actions `prepare-runner`, `next-version`, `publish-dev-release` |
| Flutter / Dart | `flutter-*`, `scripts/flutter/` | `flutter-checks.yml`, `flutter-android-apk.yml`, `flutter-release.yml`, `check_format.sh` |
| Supabase / SQL | `supabase-*` | `supabase-sql-tests.yml`, `supabase-sql-check-remote.yml`, `supabase-deploy.yml`, action `supabase-sql-tests` |
| Caller templates | `templates/<stack>/` | `templates/flutter-supabase/workflows/` |

A new technology (Node, Python, Terraform...) adds files with its own prefix (`node-*`, `python-*`...), a folder
under `scripts/` and `templates/` if needed, and a section in this README. Generic pieces never mention a
technology in their name.

## What is inside

### Reusable workflows (`.github/workflows`, called with `uses:`)

| Workflow | Purpose |
|---|---|
| `quality.yml` | actionlint (workflow files) + Gitleaks (secrets, full history); tool versions and sha256 pinned |
| `tag-release.yml` | tag `vX.Y.Z` and GitHub release only when something changed since the last one (libraries, templates); uses the repository token, no personal token needed |
| `flutter-checks.yml` | `dart format` + `flutter analyze` + `flutter test` |
| `flutter-android-apk.yml` | checks, release APK, artifact, optional `dev-latest` pre-release; skips the long build on pull requests that do not touch the native side; arm64-only by default (`target-platform`) |
| `flutter-release.yml` | checks, then tag `vX.Y.Z` and GitHub release (Flutter apps) |
| `supabase-sql-tests.yml` | migrations + `supabase/tests/*.test.sql` on a throw-away Postgres |
| `supabase-sql-check-remote.yml` | one migration and its test on a real environment, rolled back at the end |
| `supabase-deploy.yml` | `supabase db push` (self-hosted by URL, or cloud by project ref) and Edge Functions |
| `ci.yml` | this repository checking itself |
| `self-release.yml` | this repository's own manual release (calls `tag-release.yml`) |

Every workflow takes `runner-labels` (a JSON array). Projects pass `${{ vars.RUNNER_LABELS || '["ubuntu-latest"]' }}`
so a repository variable switches between GitHub runners and a self-hosted runner, with GitHub runners as the
safe fallback.

### Composite actions (`.github/actions`)

| Action | Purpose |
|---|---|
| `prepare-runner` | checks required tools, trusts git folders, installs Node.js / Java / Android SDK on demand |
| `publish-dev-release` | updates the `dev-latest` pre-release in place (never deleted), optional tag move |
| `next-version` | computes the next `vX.Y.Z` from existing releases |
| `supabase-sql-tests` | the SQL test runner (`run.sh`) and the Supabase stub (`local_stub.sql`) |

### Scripts and templates

- `scripts/flutter/check_format.sh [app-dir]`: Dart format check that ignores generated l10n files.
- `templates/flutter-supabase/workflows/`: ready-to-copy caller workflows for a Flutter + Supabase project. The
  documentation models live in `dadamagouil/models`.

## Implement it in a project

### 1. Allow the repositories to call each other

If the repositories are private: in `devops` go to Settings → Actions → General → Access and allow
repositories of the same owner to use its workflows and actions.

### 2. Copy the caller workflows

Copy the files of [`templates/flutter-supabase/workflows`](templates/flutter-supabase/workflows) into the project's `.github/workflows/` and
replace the `{{placeholders}}` (`{{app}}`, application id, Flutter version...). For example the quality check is
only this:

```yaml
name: Quality checks
on:
  push: { branches: [develop] }
  pull_request:
jobs:
  quality:
    uses: dadamagouil/devops/.github/workflows/quality.yml@develop
    with:
      runner-labels: ${{ vars.RUNNER_LABELS || '["ubuntu-latest"]' }}
```

Pin `@develop` to a tag (`@v1`) once releases exist, so a change here never breaks a project by surprise.

### 3. Configure the GitHub side

| Where | What |
|---|---|
| Environments `dev` / `prd` | Secrets: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and for deployment either `DATABASE_URL` (self-hosted) or `SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_PASSWORD` + `SUPABASE_PROJECT_REF` (cloud) |
| Secret `RELEASE_TOKEN` | Only for tag moves and writing secrets: a personal token with Contents + Workflows write |
| Variable `RUNNER_LABELS` | Optional. A **JSON list** of runner labels, for example `["self-hosted","Linux","X64"]` for your own runner; absent = GitHub runners. A value that is not valid JSON (for example the bare text `RUNNER_LABELS`) makes every workflow fail at start-up |

The `prepare-runner` action checks the tools on a self-hosted runner and says exactly what is missing.
`supabase-sql-tests.yml` always runs on GitHub runners (its Postgres is a Docker service container); `supabase-sql-check-remote.yml`, `supabase-deploy.yml` and the rest follow `runner-labels`. This repository's own `ci.yml` also reads the variable.
A runner with little memory: besides the arm64-only build, lower Gradle's memory **on the runner** in `~/.gradle/gradle.properties` (it wins over the repository's), for example `org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G`.
Running pull-request code on your own machine is only acceptable on a **private** repository: **never set `RUNNER_LABELS` to a self-hosted runner on a public repository**, a pull request from a fork would run on your own machine.

### 4. Copy the supporting files

- `.github/dependabot.yml`, `analysis_options.yaml`, `.gitignore`, PR/issue templates, `DEPLOY.md`, `CLAUDE.md`:
  from [`dadamagouil/models`](https://github.com/dadamagouil/models).
- Layout for SQL tests: `supabase/migrations/*.sql` and `supabase/tests/*.test.sql`, each test printing
  `RESULT OK` (see `supabase/README.md` in `dadamagouil/models`).

### 5. Call the actions directly (optional)

```yaml
- uses: dadamagouil/devops/.github/actions/prepare-runner@develop
  with: { commands: "git curl tar xz", android: "true" }
- id: version
  uses: dadamagouil/devops/.github/actions/next-version@develop
  with: { bump: minor }
```

### Run the SQL tests locally

```bash
SUPABASE_DIR=supabase STUB=1 .github/actions/supabase-sql-tests/run.sh "postgresql://postgres@localhost:5432/test"
```

`STUB=1` loads a minimal imitation of Supabase (roles, `auth` schema) so a plain Postgres is enough.

## Versions

Releases are tags `vX.Y.Z` created by the `Release` workflow (Actions → Release → Run workflow), only when
something changed since the last one. Callers can pin a version instead of `@develop`:
`uses: dadamagouil/devops/.github/workflows/quality.yml@v1.0.0`. Use `patch` for fixes and documentation, `minor`
for a new workflow, action or input, `major` for a change that breaks callers.

## License

MIT, see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Everything in this repository is written in English.
