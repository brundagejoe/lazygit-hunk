# lazygit-hunk

Open whatever you have selected in [lazygit](https://github.com/jesseduffield/lazygit) as a [hunk](https://github.com/modem-dev/hunk) review session, with one key.

Hunk takes over the lazygit screen; quit hunk (`q`) to come back. While hunk is open, the session is live, so an agent can read your comments with `hunk session comment list --repo . --type user`.

## Install

Requires `git`, `hunk` (`brew install hunk`), and lazygit (tested with 0.61 and hunk 0.23). The `gh` CLI is optional (see [PRs](#prs)).

```sh
git clone https://github.com/brundagejoe/lazygit-hunk.git ~/code/lazygit-hunk
~/code/lazygit-hunk/install.sh
```

The installer adds one marked block to the config lazygit loads (`lazygit --print-config-dir`, or the first file in `$LG_CONFIG_FILE`). It merges into an existing `customCommands:` list if you have one, saves a `config.yml.bak`, and can be re-run safely. The keybindings point at `bin/lazygit-hunk` in your clone, so `git pull` picks up updates without reinstalling.

```sh
./install.sh --key X       # choose the menu key (default: X)
./install.sh --config PATH # edit a specific config file
./install.sh --uninstall   # remove the block
```

## Use

Press `X` in lazygit. The menu only lists entries for the panel you're in:

| Panel | Key | Opens |
|---|---|---|
| Files | `u` | unstaged + untracked changes |
| | `s` | staged changes |
| | `a` | everything uncommitted (vs `HEAD`) |
| | `f` | the selected file or directory, everything uncommitted |
| | `b` | the whole branch vs base, including uncommitted work |
| | `p` | the GitHub PR for the checked-out branch |
| Commits / Reflog / a branch's commits | `c` | the selected commit, or the range selected with `v` |
| Commit files | `f` | the selected file in that commit or range |
| | `c` | the whole commit or range |
| Local / remote branches | `b` | the branch vs base (merge-base, same as a PR diff) |
| | `p` | the GitHub PR for the branch |
| Stash | `s` | the stash entry |
| Worktrees | `w` | that worktree's branch vs base, including uncommitted, without switching to it |

Working-tree reviews run with `--watch`, so hunk refreshes as files change (for example, when your agent addresses a comment).

### Worktrees

Everything runs in the worktree lazygit currently has open, so switching worktrees inside lazygit and then pressing `X` reviews that worktree. The hunk session's repo is the worktree path, so agents should target it with `--repo <worktree path>` (or `--repo .` from inside it).

### Base branch

"vs base" means your repo's default branch, not literally `main`. It's resolved in this order:

1. `$LAZYGIT_HUNK_BASE`
2. `git config lazygit-hunk.base` (per repo, shared by all its worktrees)
3. `origin/HEAD`
4. the GitHub default branch, via `gh`
5. `main`, then `master`

The remote-tracking branch (`origin/staging`) is used when it exists, so a stale local branch doesn't add unrelated commits to the diff. To pin it for a repo:

```sh
git config lazygit-hunk.base staging
```

If `origin/HEAD` is missing or out of date, `git remote set-head origin --auto` refreshes it. Run `bin/lazygit-hunk base` inside a repo to see what it resolves to.

### PRs

The PR view uses `hunk gh pr`, which shows GitHub's version of the diff, so it can differ from your local branch if you haven't pushed. When `gh` is installed it looks up the PR number, since hunk's own branch-to-PR lookup can fail on private repos (HTTP 422). Without `gh`, only the checked-out branch works, using hunk's lookup.

## Notes

- After hunk exits, lazygit shows "Press enter to return to lazygit". To skip that prompt for all subprocesses, set `promptToReturnFromSubprocess: false` in your lazygit config.
- Opening commit files from a stash entry isn't supported (lazygit doesn't say which panel opened them). Use the Stash panel's `s` instead.
- `bin/lazygit-hunk` works on its own too: `bin/lazygit-hunk --help`. Set `LAZYGIT_HUNK_DRY_RUN=1` to print the hunk command without running it.
