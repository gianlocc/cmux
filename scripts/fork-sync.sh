#!/usr/bin/env bash
# Sync this fork with upstream (manaflow-ai/cmux) without losing fork-local work.
#
# Branch model (see FORK.md):
#   main      — an exact mirror of upstream/main. Never commit here.
#   personal  — every fork-local change, rebased onto main after each sync.
#
# Nothing is pushed. The script prints the push commands and stops, so you
# decide when a force-push of the rebased branch is safe.
set -euo pipefail

FORK_BRANCH="${FORK_BRANCH:-personal}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_URL="https://github.com/manaflow-ai/cmux.git"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

cd "$(git rev-parse --show-toplevel)"

[ -z "$(git status --porcelain)" ] || die "working tree is dirty; commit or stash first"

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  step "Adding '$UPSTREAM_REMOTE' remote"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
  # Pushing to upstream from here is never intended.
  git remote set-url --push "$UPSTREAM_REMOTE" DISABLED
fi

STARTING_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

step "Fetching $UPSTREAM_REMOTE and origin"
git fetch "$UPSTREAM_REMOTE"
git fetch origin

step "Fast-forwarding main to $UPSTREAM_REMOTE/main"
git checkout main
AHEAD="$(git rev-list --count "$UPSTREAM_REMOTE/main..main")"
if [ "$AHEAD" != "0" ]; then
  die "main is $AHEAD commit(s) ahead of $UPSTREAM_REMOTE/main.
main must stay a pure mirror so it always fast-forwards. Move those commits:
    git branch -f $FORK_BRANCH main && git reset --hard $UPSTREAM_REMOTE/main"
fi
BEHIND="$(git rev-list --count "main..$UPSTREAM_REMOTE/main")"
git merge --ff-only "$UPSTREAM_REMOTE/main"
echo "main advanced by $BEHIND commit(s)"

step "Updating submodules to match the new main"
git submodule update --init --recursive

step "Rebasing $FORK_BRANCH onto main"
git checkout "$FORK_BRANCH"
BEFORE="$(git rev-parse HEAD)"
if git rebase main; then
  echo "rebase clean"
else
  cat >&2 <<'MSG'

Rebase stopped on a conflict. Resolve, then:
    git add <files> && git rebase --continue
To abandon:
    git rebase --abort

Common conflict spots for this fork are listed in FORK.md.
MSG
  exit 1
fi

step "Result"
git --no-pager log --oneline "main..$FORK_BRANCH"
echo
echo "Nothing has been pushed. When you are happy with the result:"
echo "    git push origin main"
echo "    git push --force-with-lease=$FORK_BRANCH:$BEFORE origin $FORK_BRANCH"
[ "$STARTING_BRANCH" = "$FORK_BRANCH" ] || echo "(you were on '$STARTING_BRANCH' before; you are now on '$FORK_BRANCH')"
