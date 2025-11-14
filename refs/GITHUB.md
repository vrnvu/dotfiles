GitHub 

General ideas
- Author and Assignee are owners
- Assign one reviewer (not "request review")
- Author clicks "Merge when ready"
- Merge commits (preserves PR #, easy revert)
- Merge queue handles testing and creates merge commit

Merge Strategies

- Squash and merge: One commit in main.  Lose individual commit history.  Can only revert entire feature.
- Merge commit: All commits preserved + merge commit.  PR # visible in git log.  Can revert individual commits or entire feature.  Discussion attached to PR.
- Rebase-merge: All commits preserved, linear history.  No merge commit, no PR # in log.  Can revert individual commits.  Harder to trace back to PR.

Example workflow with jj 

Create feature
- jj new main
- jj bookmark create feature-auth
- jj commit -m "feat: add user model"
- jj commit -m "feat: add JWT tokens"

Move bookmarks
- jj tug 

Push all bookmarks or just feature
- jj git push --allow-new
- jj git push --bookmark feature-auth --allow-new

On GitHub
- Create PR
- Assign one reviewer
- Click "Merge when ready"

Review feedback received
- jj new feature-auth
- jj commit -m "fix: address review feedback"
- jj commit -m "fix: address review feedback"
- jj tug
- jj git push

TODO After approval (optional cleanup)
- jj squash/split/...
- jj tug

TODO force, foce-with-lease, jj doesnt allow
- jj git push --force --ignore-immutable
- Comment on PR: "Cleaned up"

Merge via GitHub UI
- Merge queue runs CI
- Auto-merges with merge commit

Stacked PRs with jj

Create stack
- jj new main
- jj commit -m "feat: add authentication base"
- jj commit -m "feat: add JWT tokens"
- jj commit -m "feat: add refresh tokens"

Create bookmarks for each change
- jj bookmark create auth-base -r <change1-id>
- jj bookmark create jwt-tokens -r <change2-id>
- jj bookmark create refresh-tokens -r <change3-id>

Push as separate PRs
- jj git push --bookmark auth-base --allow-new
- jj git push --bookmark jwt-tokens --allow-new
- jj git push --bookmark refresh-tokens --allow-new

On GitHub
- Create PR #1: auth-base → main
- Create PR #2: jwt-tokens → auth-base
- Create PR #3: refresh-tokens → jwt-tokens
- Each PR is independently reviewable

Fix earlier change after feedback
- jj edit <change1-id> (auth-base)
- jj commit -m "fix logging issue"
- All descendants automatically rebase
- Push updated stack: jj git push --bookmark auth-base --bookmark jwt-tokens --bookmark refresh-tokens

Merge order
- Merge PR #1 first
- Update PR #2 base to main on GitHub
- Merge PR #2
- Update PR #3 base to main on GitHub
- Merge PR #3

Stacked PR with gh (TODO)

Create PRs with correct base branches
- gh pr create --head auth-base --base main --fill
- gh pr create --head jwt-tokens --base auth-base --fill
- gh pr create --head refresh-tokens --base jwt-tokens --fill

Merge workflow
1. Merge PR #1
   - gh pr merge <PR-NUMBER-1> --auto --merge
   
2. Retarget and merge PR #2
   - gh pr edit <PR-NUMBER-2> --base main
   - gh pr merge <PR-NUMBER-2> --auto --merge
   
3. Retarget and merge PR #3
   - gh pr edit <PR-NUMBER-3> --base main
   - gh pr merge <PR-NUMBER-3> --auto --merge

Merge options
- --squash: Squash and merge (one commit)
- --merge: Create merge commit (preserves individual commits)
- --rebase: Rebase and merge (linear history)
- --auto: Merge when checks pass (uses merge queue if enabled)

Mark all as ready then retarget as they merge
- gh pr ready <PR-NUMBER-1>
- Wait for PR #1 to merge
- gh pr edit <PR-NUMBER-2> --base main && gh pr ready <PR-NUMBER-2>
- Wait for PR #2 to merge
- gh pr edit <PR-NUMBER-3> --base main && gh pr ready <PR-NUMBER-3>

Check PR status
- gh pr list --author @me
- gh pr view <NUMBER>
- gh pr status

Local code review

Idea from https://matklad.github.io/2023/10/23/unified-vs-split-diff.html

- git fetch upstream refs/pull/1234/head
- git switch --detach FETCH_HEAD
- git reset $(git merge-base HEAD main)

In jj:

- jj new main
- jj restore -f <change-id>
- jj restore -f <bookmark>

Operations

Basic queries
- jj log -r :: --limit 10
- jj log -r 'author("username")' --limit 10
- jj log -r 'change_id(xynz)' (explicit change-id lookup)

Find PR merge commit
- jj log -r 'description(glob:"*#3374*")'

Find all commits from a PR (given only merge commit)
- jj log -r 'fork_point(<merge-commit>-)..<merge-commit> ~ <merge-commit>'
- With alias: jj log -r 'searchPR(xynzlyso)'

```toml
[revset-aliases]
'searchPR(x)' = 'fork_point(x-)..x ~ x'
```

Search git history
- Find all branches: git branch --list
- Search commit messages: git log --grep="auth"
- Find PR merge commits: git log --grep="#2734"
- Find all commits from a PR: git log <merge-commit>^2 --not <merge-commit>^1
- Search by author: git log --author="username"
- Pretty log: git log --oneline --graph

Revert changes
- Revert single commit: git revert <commit>
- Revert merge commit: git revert -m 1 <merge-commit>
- Undo last commit (keep changes): git reset --soft HEAD~1
- Undo last commit (discard changes): git reset --hard HEAD~1

