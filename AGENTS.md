# Agent Guide

This document defines the global rules for any automated agent working in this repository.

Subdirectories may contain their own `AGENTS.md` files. Those files refine or override parts of this guide for files in that directory. Before you read or modify any file, you **must** check for an `AGENTS.md` in the same directory and follow any additional instructions it contains.

---

## Repository Layout

You must respect this layout unless explicitly instructed otherwise by the user or by a more specific `AGENTS.md`.

- `AGENTS.md` (this file)  
  Global rules for all agents in this repository.

- `src/`  
  This is the root for all project source code.  
  - All new code, libraries, modules, and application logic you create must live under `src/` (or its subdirectories), unless a directory‑specific `AGENTS.md` explicitly says otherwise.  
  - Do not create new source trees outside `src/` without explicit user approval.

- `docs/`  
  All planning, research, and human‑oriented documentation lives here.  
  - `docs/AGENTS.md`: rules for documentation work.  
  - `docs/plans/`: long‑lived plans and task tracking.
    - `docs/plans/AGENTS.md`: planning‑specific rules.
    - `docs/plans/index.md`: overview of active and past plans.
    - `docs/plans/tasks.md`: prioritized list of next tasks and upcoming tasks.
  - `docs/research/`: research notes, experiments, and findings.
    - `docs/research/AGENTS.md`: research‑specific rules.

- `install.sh`  
  Environment setup or project bootstrapping. Modify with care and only when necessary as part of a planned change.
  - Never execute `./install.sh` or other installer entrypoints directly; defer manual runs to the human operator and rely on scripted validation instead.

If you are unsure where something belongs:
1. Prefer `docs/` for writing.
2. Prefer `src/` for code.
3. Ask the user before introducing a new top‑level directory.

---

## AGENTS.md Discovery and Precedence

Before you open, read, or modify any file:

1. Determine the directory containing that file.
2. Check for `AGENTS.md` in that directory.
   - If present, read it and follow its instructions for any work in that directory.
3. Also respect:
   - This root `AGENTS.md` as the default global policy.
   - Any relevant `AGENTS.md` in ancestor directories, if the project is structured that way.

Precedence rules:

- More specific scope beats less specific scope:
  - File‑directory `AGENTS.md` > parent directory `AGENTS.md` > root `AGENTS.md`.
- If instructions conflict:
  - Follow the most specific applicable `AGENTS.md`.
  - If a direct user instruction conflicts with an `AGENTS.md`, surface the conflict to the user and ask how to proceed when possible. Do not silently ignore repository governance rules.

You must never modify or delete an `AGENTS.md` file unless the user explicitly instructs you to do so.

---

## Handling Inbound Requests

### If the request is the first request in a session

Determine whether the user is:

- Asking you to perform an entirely new, unplanned unit of work, or
- Attempting to continue work on an already planned problem domain.

You must always anchor your work to a plan (existing or new) and to concrete tasks in `docs/plans/tasks.md`.

#### If the first request in a session concerns an open topic

1. Open `./docs/plans/index.md` and identify which existing planned work best fits the request.
2. Read the corresponding plan file(s) and any linked documentation and resources.
3. Open `./docs/plans/tasks.md`:
   - Reprioritize any currently identified “next tasks” and “upcoming tasks” as needed.
   - Do not remove or discard existing tasks; only adjust ordering and, if needed, update their descriptions for clarity.

4. Respond to the user with a structured markdown document that includes:
   - **Understanding of the request**  
     Your concise summary of what the user is asking for.
   - **Context within existing plans**  
     Which plan(s) this relates to and how it changes or reinforces them.
   - **Impact on current tasks**  
     What you reprioritized and why.
   - **Open questions / assumptions**  
     Any questions you need answered, or explicit assumptions you propose to make.
   - **Planned research (if any)**  
     What you intend to investigate before writing or changing code and where you will record it (`docs/research/...`).
   - **Concrete next action**  
     The next specific thing you will do as soon as the user confirms you may proceed, referencing a task in `docs/plans/tasks.md`.

The order and formatting may be adjusted to fit the context, but these elements should all be present.

#### If the first request in a session concerns new, unplanned work

1. Open `./docs/plans/index.md` and scan existing plans to understand whether this new work overlaps or conflicts with them.

##### If the new work impacts existing planned work

1. Analyze how the new request interacts with existing plans:
   - Overlaps: is the new work already covered?
   - Dependencies: does it need to be done before/after existing work?
   - Conflicts: does it change goals, priorities, or non‑goals?

2. Respond to the user with a structured markdown document that includes:
   - **Summary of the new request.**
   - **Impact on existing plans**, e.g.:
     - Possible duplication.
     - Need to expand or split current plans.
     - Changes in priority or sequencing.
   - **Options for organizing the work**, such as:
     - Integrate the new request into an existing plan.
     - Create a new plan linked to existing ones.
     - Defer or explicitly decline the new work.
   - **Recommendation**  
     Your suggested approach with pros/cons.
   - **Proposed updates to `index.md` and `tasks.md`**, but do not apply them until the user agrees.

3. Once the user chooses an option:
   - Create or update plan file(s) under `docs/plans/`.
   - Update `docs/plans/index.md` and `docs/plans/tasks.md` accordingly.

##### If the new work does not impact existing planned work

1. Create a new plan file under `docs/plans/` with a unique, human‑readable slug:
   - Example: `docs/plans/<short-problem-summary>.md`
2. Add an entry to `docs/plans/index.md` referencing the new plan.
3. Add one or more tasks related to this plan to `docs/plans/tasks.md`.

4. Respond to the user with a structured markdown document that includes:
   - **Understanding of the request.**
   - **Where the new plan will live** (path and slug).
   - **Initial goals and non‑goals.**
   - **Open questions / assumptions.**
   - **Any research you will perform before coding.**
   - **Concrete next action**, tied to a specific task entry in `docs/plans/tasks.md`.

Again, you may adjust the order and format, but all elements must be accounted for.

### Subsequent requests in a session

If the request is not the first in a session:

- Assume it relates to the current active plan and task unless otherwise specified.
- If the user appears to switch context, explicitly state which plan/task you believe they are referring to and confirm if needed.
- Keep `docs/plans/tasks.md` up to date with any progress before switching context.

---

## Planning Work

Planned work provides structure for both you and the user. All non‑trivial work should be associated with a plan and a set of discrete tasks.

### Work units

You should model work at three levels:

1. **Plan** (`docs/plans/<slug>.md`)
   - Defines the problem, goals, constraints, approach, and milestones.
2. **Task** (rows in `docs/plans/tasks.md`)
   - Smallest unit of work that:
     - Can be completed in a short, focused session.
     - Can be manually verified by the user.
     - Produces a tangible artifact (code changes, documentation, test results, etc.).
3. **Change** (commits / PRs / branches)
   - One or more changes to the repository implementing a specific task.

### Plan files

When creating or updating a plan file under `docs/plans/`:

- Include, at minimum, sections for:
  - **Problem / Context**
  - **Goals**
  - **Non‑Goals**
  - **Constraints / Assumptions**
  - **High‑Level Approach**
  - **Milestones / Phases**
  - **Risks and Tradeoffs**
  - **Open Questions**
  - **Related Research** (links to `docs/research/...`)

- Keep plan documents concise but precise. Plans should guide implementation, not duplicate code.

### Tasks

Maintain `docs/plans/tasks.md` as the central task backlog.

- Each task should include:
  - An identifier or slug.
  - A brief description.
  - Associated plan slug.
  - Status (e.g., `next`, `upcoming`, `in-progress`, `blocked`, `done`).
  - Priority or ordering.
  - Optional: dependencies on other tasks.

- When defining tasks:
  - Break work down so that each task:
    - Produces something the user can inspect (e.g., a diff, doc, or test output).
    - Moves the plan measurably closer to completion.
    - Is small enough that you can complete it without needing further decomposition mid‑task.

- When updating tasks:
  - Do not delete tasks unless explicitly requested.
  - Prefer marking tasks as `done`, `superseded`, or `won't-do` with a short note.

### When to perform research

You should create or update research entries under `docs/research/` when:

- You need to evaluate libraries, tools, or APIs.
- You need to understand a complex domain or specification.
- There are multiple viable approaches and you need to compare them.
- External information is required (e.g., protocol specifications, performance benchmarks).

For research:

- Create `docs/research/<slug>.md` with:
  - **Questions**
  - **Findings**
  - **Options considered**
  - **Decision / Recommendation**
  - **References / Links**

- Update `docs/research/index.md` (if present) to include the new research item.

Research should be outcome‑oriented: focus on decisions and tradeoffs, not raw notes.

---

## Beginning Work (Implementing Tasks)

Once a task is selected and a plan is in place, follow these steps to begin work.

### Select and confirm the task

1. From `docs/plans/tasks.md`, identify the highest‑priority `next` task you are working on.
2. Confirm the task’s scope by briefly restating it in your own words in your response to the user.
3. If the task is ambiguous but you can reasonably infer missing details, state your assumptions explicitly and proceed. Only block on questions when essential.

### Git and branches

When making code changes:

1. Ensure your working copy is based on the latest main branch (or whichever default branch is specified in project‑specific docs).
2. Create a branch dedicated to the current task:
   - Example pattern (adjustable per project):  
     - `task/<short-slug>` or `feat/<short-slug>` or `fix/<short-slug>`
3. Keep the branch focused on a single task whenever possible.

Do not merge branches into main yourself unless explicitly instructed. Instead, prepare your changes so the user can review and merge.

### Working in `src/`

- All new code and refactors must be placed under `src/` unless a directory‑specific `AGENTS.md` or the user directs otherwise.
- Do not create parallel code trees outside `src/`.
- If a task seems to require a new top‑level structure (e.g., `services/`, `packages/`), propose it to the user before proceeding.

### Implementation process

For each task:

1. **Read context**
   - Check for `AGENTS.md` in any directory whose files you will touch.
   - Review relevant plan file(s) and research entries.
   - Scan the existing code in `src/` that you will be interacting with.

2. **Design at a small scale**
   - Write a short, concrete design sketch in your response (1–3 paragraphs or bullets) outlining:
     - The main changes you will make.
     - Which files you will touch or create.
     - The shape of any new functions, classes, or modules.
   - Adjust based on user feedback if they respond before you proceed.

3. **Use tests wherever possible**
   - Prefer test‑driven development:
     - Add or update tests that describe the desired behavior.
     - Run tests after making changes.
   - If no tests exist:
     - Propose minimal, focused tests and add them as part of the task.
   - If tests cannot be written (e.g., too early in a spike), state why and what manual verification you will rely on.

4. **Keep changes minimal and coherent**
   - Implement only what is needed for the current task.
   - Avoid large, unplanned refactors. If you discover necessary refactors:
     - Note them and propose a follow‑up task in `docs/plans/tasks.md`.

5. **Record decisions**
   - For nontrivial design decisions, update the related plan or research file with:
     - What you chose.
     - Alternatives you considered, if any.
     - Why the final choice was made.

### Completion criteria and user handoff

When you believe a task is complete:

1. Update `docs/plans/tasks.md`:
   - Mark the task as `done` (or equivalent) and, if relevant, reference the branch or commit.
2. In your response to the user, provide:
   - **Summary of changes**
     - High‑level bullet list of what was implemented.
   - **Files touched**
     - A list of modified/created files, grouped by directory.
   - **Tests run**
     - Which test commands were executed and their outcomes.
     - If no tests were run, explain why.
   - **Manual verification steps**
     - Exact commands and/or steps the user can run to confirm the behavior locally.
   - **Known limitations / follow‑ups**
     - Any remaining issues or suggested follow‑up tasks, with proposed entries for `docs/plans/tasks.md`.

Do not start the next task automatically unless the user has made that expectation explicit. Instead, wait for confirmation or a new instruction.

---

## Research and Documentation Work

When you perform research or documentation work without code changes:

- Prefer to create or update:
  - `docs/research/<slug>.md` for investigations.
  - `docs/plans/<slug>.md` when the work is about planning.
- Keep these documents:
  - Traceable (clear titles and slugs).
  - Linked from index files (`docs/research/index.md`, `docs/plans/index.md`) when such files exist.
- Summarize key outcomes in your response so the user does not need to read raw notes to understand your conclusions.

---

## Interaction with the User

- Be explicit about:
  - What you understand the request to be.
  - What you will do next.
  - What you need from the user (if anything) before proceeding.
- Minimize unnecessary questions:
  - When reasonable, state assumptions and proceed, rather than blocking.
  - Clearly label assumptions so the user can correct them.
- Keep responses structured:
  - Prefer headings and bullet lists over long paragraphs.
  - Always include “Next action” or “Next steps” so the user knows what you plan to do.

---

## Things You Must Not Do

Unless explicitly instructed by the user or by a more specific `AGENTS.md`, you must not:

- Modify or delete any `AGENTS.md` file.
- Introduce new top‑level directories outside `src/`, `docs/`, or other existing roots.
- Perform broad, repository‑wide refactors without a plan documented under `docs/plans/`.
- Remove or rewrite significant portions of code without explaining why and how it aligns with the current plan.
- Ignore failing tests or errors:
  - If tests fail, you must either fix the issue or explain why it cannot be addressed within the current task.

---
