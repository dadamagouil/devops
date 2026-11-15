# Contributing

- Everything (code, comments, documentation, commit messages, issues) is in **English**.
- **One implementation per problem.** When the same problem is solved twice, keep the best of both
  and say in a comment why.
- **Comments explain the why** (a constraint, a trap), not the what. Each file starts with what it is for.
- **Small and readable**: one file, one subject; a workflow or script that grows past ~200 lines is split.
- **One technology, one prefix.** Workflow and action names start with the technology they serve (`flutter-`,
  `supabase-`...); generic pieces have none. Scripts and templates live in a folder per technology.
- **Inputs over hard-coded names**: nothing project-specific (app name, package id, paths) in a reusable
  workflow or action; use inputs with sensible defaults.
- **Secrets**: never in the repository. Reusable workflows declare the secrets they accept explicitly.
- **Pinned downloads**: any downloaded tool has a pinned version and a sha256 check.

## Checks

```bash
actionlint                    # workflow files (the CI downloads a pinned version)
bash -n scripts/*.sh .github/actions/*/*.sh
```

Pull requests run the `CI` workflow (this repository calls its own `quality.yml`).

## Documentation

Every change to a workflow, action, script or caller template updates `README.md` (and the documentation model in `dadamagouil/models` that mentions it)
in the same pull request.
