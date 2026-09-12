# Share documentation across branches

Each branch has its own files. Editing or pushing README.md on one branch does not update the others. Use a **documentation-only commit**, then cherry-pick it. Do not merge entire implementation branches just to share a README.

## Recommended workflow

Start with a clean working tree. Commit unrelated work separately, or stash it and restore it after returning to the original branch. Do not discard changes to make switching easier.

After editing shared documentation on main:

```powershell
git switch main
git add README.md docs/ICONS.md
git commit -m "Update icon documentation"
$docsCommit = git rev-parse HEAD

git switch android-15
git cherry-pick $docsCommit

git switch permanent-notification
git cherry-pick $docsCommit

git switch root
git cherry-pick $docsCommit

git switch main
git push origin main android-15 permanent-notification root
```

Run commands step by step and stop if one fails. Stage only the files you actually changed; for a README-only edit, use `git add README.md`. `$docsCommit` holds the original commit ID; the cherry-picked commits may get different IDs.

If your edit starts on a different branch, capture its documentation commit ID and cherry-pick onto the other three branches, skipping the source branch.

## Conflicts and branch-specific content

If cherry-pick reports a conflict, edit the marked sections to preserve each branch's method and compatibility notes. Stage the resolved files and run `git cherry-pick --continue`. Use `git cherry-pick --abort` to cancel that cherry-pick without discarding earlier successful copies. Inspect `git diff --check` and `git status` before pushing.

Cherry-pick applies the change rather than replacing the whole README. This matters because main uses legacy broadcasts, android-15 uses best-effort callbacks, permanent-notification uses a foreground service, and root uses a privileged listener. Keep those differences accurate.

For shared material, prefer a dedicated file such as docs/ICONS.md and link it from every README. It still needs synchronization, but conflicts are less likely.

GitHub release descriptions are separate from repository Markdown. Updating a README does not change an existing release page or rebuild its APKs; update the release description separately when needed.
