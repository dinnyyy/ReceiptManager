# AGENTS.md

## Git Workflow

This project only uses the `main` branch.

There are currently:

- No feature branches
- No branch protection
- No CI/CD
- No pull requests

### Before making changes

Always make sure you are on `main` and pull the latest changes:

```bash
git checkout main
git pull origin main
```

### After making changes

Once you have finished implementing the requested changes:

1. Check the changes:

```bash
git status
git diff
```

2. Commit the changes to `main` with a clear commit message:

```bash
git add .
git commit -m "Describe the changes"
```

3. Push directly to `main`:

```bash
git push origin main
```

### Important

- **Always commit completed changes to `main`.**
- **Always push completed changes to `main`.**
- Do not create or use other branches.
- Do not force push.
- Do not delete or reset existing work.
- Do not commit secrets such as `.env` files or API keys.
- Make sure the requested changes are working before committing.
- Keep commit messages short and descriptive.

The goal is to automatically leave the repository with the completed, tested changes committed and pushed to `main`.
