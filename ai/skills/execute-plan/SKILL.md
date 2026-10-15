---
name: execute-plan
description: Execute an existing implementation plan phase by phase, from a plan file or a Linear project. Use for "execute the plan", "run the plan", "implement <plan>", or when handed a plan path or Linear project. Resolves each phase's repo and workspace, runs each PR-ready slice through the pr skill, and records progress in the plan file or reads it from Linear.
---

Read `~/.agents/skills/_shared/instructions.md` for the plan root, repo registry, and checkout layout. Refer to `plan` for the plan format and `pr` for how each slice is shipped. Invoking this skill authorizes creating branches, pushing them, opening PRs for the plan's slices, pushing commits to the default branch of `pr` direct repos, and rebasing stacked PRs once their parent merges — nothing else.

## 1. Resolve the plan

`$ARGUMENTS` is a plan path, a name under the plan root (`<plan-root>/*/plans/<name>.md`), or a Linear project (URL, `P-` ID, or name, optionally narrowed to a milestone). Linear project → follow [Linear projects](#linear-projects) where it differs from the steps below. Read the plan in full.

- No `## Phase` headings → run `plan` first and confirm before executing.
- `## Open questions` lists a blocker → stop and ask; do not guess.
- A phase already marked `**Status:** done` → skip it. Marked `**Status:** open — <PR URL>` → its PR exists; resume it at step 4.4 in its workspace, and replace the line when it finishes.
- The user names a phase → run only that phase.

## 2. Schedule slices

Each phase is one slice unless its `**PR boundary:**` says `Not a PR boundary`, in which case merge it into the next phase's slice; the merged slice waits on both phases' dependencies.

A slice is ready when every `**Depends on:**` entry is met: `(merged)` → that phase's PR is merged (`gh pr view <url> --json state`); `(stacked)` → that phase's PR is open. A phase in a direct repo meets both once its commits are pushed. A dependency whose PR was closed unmerged counts as blocked. Older plans without `**Depends on:**`: follow `## Implementation order` and `**Parallelizable:**`, treating each sequential phase as `(merged)` on the one before.

First, for each done `(stacked)` phase whose parent PR has merged: in a workspace from step 3, check out its branch, run `git rebase --onto origin/<default> <parent-head>` (parent head: `gh pr view <parent-url> --json headRefOid`), `git push --force-with-lease`, and `gh pr edit <url> --base <default>`. Then rebase each phase stacked on the one you just rebased the same way, onto its parent's new branch tip, cutting at the parent's head from before its rebase; its base stays the parent's branch. Conflicts → `git rebase --abort` and report it.

Run every ready slice as one batch through step 4; whenever a batch stage ends, start a new batch with whatever became ready. Slot repos limit themselves (`devslot claim` waits when no slot is free). Repos without slots run one slice at a time per repo, because one checkout holds one branch. Slices still waiting on an unmerged PR stay pending: report them and stop; rerunning the skill picks them up. A blocked slice → let running slices finish, start nothing new, and report.

## 3. Workspace per slice

Resolve `**Repo:**` through the registry (fall back to `in <repo>` text or the current repo; ambiguous → ask). Then:

- Slot repo (`dev<N>` beside the default worktree): `path=$(devslot claim <branch> <repo-root> --note "<plan>:<phase>")`; stacked → then `git -C "$path" reset -q --hard origin/<base>` on the fresh branch.
- Direct repo (see `pr`): the checkout itself, on the default branch. Its slices run one at a time and never branch.
- Otherwise: in the default checkout, require a clean tree, then `git fetch origin && git switch -c <branch> origin/<base>`.

Base: `<default>`, or for a `(stacked)` dependency, that phase's branch. Branch: `<prefix>/<slug>`, prefix from `## Handoff to PR skill`; default prefix is the user's usual one in that repo (`git log --author`), slug from the phase name.

## 4. Run a batch

Subagents cannot run the multi-model review, and a subagent call blocks you until every subagent started in that turn returns. So subagents do only short, bounded work; you review, and you do all waiting with background shell processes. Give each subagent: the absolute workspace path, the branch, the base branch when stacked (for `gh pr create --base`), the phase text verbatim (objective, actions, verification, exit criteria), and the instruction to follow the `pr` skill and work only in that directory.

1. **Implement.** One subagent per slice, all started in one turn. Each follows `pr` steps 1–3, commits locally, and stops without pushing. It does not split an oversized diff. Final message: what it built, the checks it ran, the diff size with a proposed split if over the limit, anything left undone.
2. **Review.** Diff over the `pr` size rule → do not ship; mark the phase blocked with the size and proposed split. Otherwise run `pr` step 4 ([review.md](../pr/review.md)) yourself on `git -C <path> diff origin/<base>...HEAD`, one `review_with_models` call per slice in the same turn, and validate each finding.
3. **Open.** One subagent per slice, all in one turn. Each gets the verified findings, fixes them, reruns checks, follows `pr` step 5, and returns as soon as the PR exists; it must not run `pr` step 6. Final message: the PR URL, the checks it ran, anything left undone. Append `**Status:** open — <PR URL>` under the phase heading. If step 2 found blockers, rerun those lenses once on `origin/<base>...<branch>`; new blockers → a fix subagent.
4. **Watch.** For each PR, start `gh pr checks <url> --watch` as a background process and keep its pid. Then go back to step 2 of this skill: start the next batch with whatever became ready (stacked children are ready now) and run it through steps 1–3 while the checks run. Between stages, and at least every 10 minutes, poll the pids with `shell_command_status` and pull review threads and comments as in `pr` step 6.3. Then:
   - Checks failed → `pr` step 6.2: flaky → rerun once; also fails on the base branch → report; otherwise a fix subagent.
   - Unresolved thread or unanswered comment → a fix subagent with the thread text; it applies `pr` step 6.4.
   - A fix subagent gets the path, branch, PR URL, and one failure or thread. It fixes, pushes new commits (never amend or force-push), replies, and returns. After it pushes, restart the watch for that PR.
   - `pr`'s return-early conditions apply per slice: a scope/design decision, a question only the user can answer, or the same CI failure after 3 fix attempts → mark the slice blocked with the question and move on.
   - Checks green and every thread resolved or answered → the slice is finished.

When the slice is finished:

- Confirm the PR exists and matches the branch: `gh pr view <url> --json state,headRefName`.
- Slot repo → `devslot release <path>` (it refuses dirty or unpushed trees; resolve that first, do not force).
- Otherwise → `git switch <default>` in that checkout.
- Set the phase's status line (append one if missing) to `**Status:** done — <PR URL>`, or `**Status:** blocked — <one line>`.

Direct-repo slices skip the branch, PR, and thread steps: step 3 pushes, step 4 watches only CI on the pushed commit, and the status links the last commit (`**Status:** done — <commit URL>`).

Only these status lines may be written into the plan; leave every other line as is.

## Pi: no batches

If the `subagent` tool lists a `pr-worker` agent, this section replaces step 2's batching paragraph and step 4's intro and sub-steps 1–3; everything else applies as written.

- **Start.** Launch each slice as soon as it is ready: one background `pr-worker` per slice, each its own `subagent` call, with the workspace path, branch, base when stacked, the phase text verbatim (and the Linear issue ID), and the instruction to work only in that directory and stop once the PR exists. Keep each slice's PR URL and worker run id for this session. Do not wait for sibling slices. Step 2's per-repo limits still apply.
- **Return.** Blocked, or over the size rule → mark the phase blocked with its reason. Otherwise check its findings table: every blocker fixed or rejected with evidence; a rejection you doubt → resume that worker with your objection. Append `**Status:** open — <PR URL>`, start any slice that became ready, and continue at step 4.4.
- **Watch.** In step 4.4, `pr_track` each PR with `mode: "auto"` instead of `gh pr checks --watch` and polling, and act on its wakes and `pr_status`. A fix goes to the `pr-worker` that built the PR: check its run with `subagent` `status`, then `resume` it with the PR URL and one failure or thread. No run id, or resume refused → launch a fresh `pr-worker` with the same model, given the path, branch, PR URL, and that failure or thread, and note the fallback in the report.
- **Report** once no worker is running and every tracked PR is finished or blocked.

## 5. Report

When no slice is ready and no PR is still being watched: list each phase with its PR URL, blocker, or the merge it waits on; slots released; stacked PRs rebased or with rebase conflicts; and anything the user must decide. Do not merge, transition issues beyond `pr`'s claim, or force-push beyond the stacked rebase.

## Linear projects

The project is the plan: its description and milestones are context, each issue is a phase, and Linear and GitHub hold all state, so nothing is written back beyond `pr`'s claim.

- **Resolve.** `get_project` with milestones, every issue in the project (`list_issues`, paging), and `get_issue` with relations for each open issue. A named milestone → only its issues. Skip completed and canceled issues. A parent issue's sub-issues are its phases; the parent is not one.
- **Slices.** An issue is a slice only if it needs a code change in a repo. Investigations, design decisions, sign-offs, deploy or ops steps outside a repo, and issues assigned to someone else are left to the user: never started, listed in the report with the reason, and their dependents wait on them. Resolve each slice's repo from its title and description through the registry; collect every ambiguous one and ask once before starting.
- **Depends on.** Each `blocked by` relation, including blockers outside the project, is a `(merged)` dependency. It is met when the blocker is completed or its PR is merged; a canceled blocker is blocked. There are no stacked dependencies.
- **Branch.** The issue's `gitBranchName`, so Linear links the PR. Give the implement subagent the issue ID so `pr` step 1 claims it.
- **Status.** Never written. Find each issue's PR with `gh pr list --head <branch> --state all`: open → resume at step 4.4; merged → done.

## Rules

- Never fabricate PR URLs or check results; quote the subagent's evidence.
- One slice per branch; never reuse a workspace for two slices at once.
- Do not edit plan prose or Linear issues and projects, reorder phases, or start phases the plan marks blocked.
- When a slice is blocked, do not retry it with a different design; report and ask.
