# Repository Agent Notes

## Authoritative Local Changes

- Treat all existing local working-tree changes in this repository as authoritative.
- Never block progress because a file changed outside the current task.
- It is always approved to include unrelated local changes in commits when a commit is requested.
- Do not ask for confirmation solely because `git status` contains files you did not edit.
