Jujutsu (jj)

References
- https://jj-for-everyone.github.io/github.html
- https://steveklabnik.github.io/jujutsu-tutorial/real-world-workflows/intro.html
- https://flames-of-code.netlify.app/blog/my-jj-workflow/
- https://kubamartin.com/posts/introduction-to-the-jujutsu-vcs/#pattern-stacked-prs

Overview
- New source version control (SVC) compatible with Git, Mercury
- Designed for simplicity and ease of use
- Enables powerful workflows: interdiff, better patches, rebases
- Works with tools like Tangled, Gerrit, GitButler

Setup
- jj git init --colocate
- jj git remote add origin git@tangled.sh:arnau.tngl.sh/log
- jj bookmark create main
- jj bookmark track main@origin

Basic commands
- jj log
- jj diff
- jj show
- jj undo
- jj redo

Working with changes
- jj commit -m "message" (equivalent to new + describe)
- jj new -A $parent (rebases)
- jj new $parent (branches)
- jj new -B $child
- jj edit
- jj squash
- jj rebase -r $parent

Sync with remote
- jj tug (alias for fetch + rebase)
- jj git fetch
- jj git push
- jj git push --change @-

Bookmarks
- jj bookmark move main --to @-

With GitHub
- gh pr create --head push-qokvwvwxkwou --base main --fill

