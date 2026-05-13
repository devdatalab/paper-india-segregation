# Codex Instructions for HPC

This repository is being edited through Codex on an HPC Linux environment.

## Safety rules

- Do not run heavy computation on the login node.
- Light commands are allowed: ls, find, grep, rg, git status, git diff, head, tail, wc, and small scripts.
- For expensive jobs, write an sbatch script instead of running directly.
- Do not overwrite raw data.
- Do not delete large folders.
- Before making large changes, summarize the intended edits.

## Workflow

- Inspect the repository first.
- Explain the plan before editing.
- Keep changes small and reviewable.
- Use git diff to verify changes.
- Prefer writing logs, diagnostics, and temporary files under tmp/, logs/, or scratch/ if those folders exist.
