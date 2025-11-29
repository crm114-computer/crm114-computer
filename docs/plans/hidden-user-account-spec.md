# Hidden User Account Spec Plan

## Problem / Context
- The installer needs a definitive specification for the `crm114` service account (UID/GID, attributes, permissions, messaging) before provisioning logic can be implemented safely.
- Current documentation in `docs/plans/hidden-user-bootstrap.md` states high-level requirements but lacks a single source of truth describing attribute values, rationale, and operator-facing narratives.
- Without a finalized spec, provisioning, hiding, and idempotence work risk drift, conflicting assumptions, or user confusion.

## Goals
- Choose a UID/GID strategy (reserved static vs. auto-assigned) and document detection/repair logic for collisions.
- Enumerate every required DirectoryService attribute (shell, home path, primary group, IsHidden, AuthenticationAuthority, SecureToken posture, password storage expectations).
- Define filesystem requirements for `/Users/.crm114` (ownership, permissions, creation flow) and how to validate them.
- Script the exact Gum messaging/narration that explains why the account is created, what it does, and how the operator can inspect it safely.
- Produce acceptance criteria that downstream provisioning/hiding tasks can reference unambiguously.

## Non-Goals
- Implementing account creation or removal logic (covered by other tasks).
- Managing runtime automation performed by the `crm114` account.
- Designing launch agents/daemons or secure logging for account usage (future plans).

## Constraints / Assumptions
- Target machines are Apple Silicon macOS with `sysadminctl`, `dscl`, `createhomedir`, `/usr/libexec/PlistBuddy`, and `dsmemberutil` available.
- The hidden account must remain invisible to loginwindow/Fast User Switching and must not own GUI sessions.
- SecureToken should stay disabled to avoid FileVault implications unless future requirements change.
- The spec must be consumable by POSIX sh scripts and automated tests with no external dependencies beyond built-in tools.

## High-Level Approach
1. **UID/GID Policy**: Evaluate static UID (e.g., 550) vs. auto-assigned; define detection rules, collision handling, and documentation language.
2. **Attribute Matrix**: List each DirectoryService key/value pair (home, shell, password policy, AuthenticationAuthority, groups, IsHidden) plus required filesystem state.
3. **Messaging Narrative**: Draft Gum/simple-mode copy explaining preflight checks, creation intent, verification, and safety guidance.
4. **Acceptance Checklist**: Capture verification steps (e.g., `dscl` reads, permission checks) that provisioning/hiding steps must satisfy; integrate into tests later.
5. **Documentation Updates**: Feed finalized decisions into `docs/research/hidden-user-bootstrap.md`, the parent plan, and installer copy references.

## Milestones / Phases
1. **UID Strategy Finalization** – Document decision, detection flow, and collision handling playbook.
2. **Attribute & Filesystem Spec** – Complete the field matrix + required permissions/ownership notes.
3. **Messaging & Acceptance Criteria** – Write Gum/simple copy, list operator assurances, and define verification bullets.
4. **Plan/Research Integration** – Update related docs to reflect the finalized spec and expose it to implementation tasks.

## Risks / Tradeoffs
- Choosing a static UID could conflict with existing local users; auto-assigned IDs risk inconsistency across machines. Decision must balance predictability with safety.
- Overly prescriptive specs might fail on older macOS builds; need conditional notes where behavior differs.
- Messaging that reveals too much implementation detail could confuse operators; must stay concise while transparent.

## Decisions
- UID/GID: allow macOS to auto-allocate the next available UID/GID, but detect collisions and repair attributes if `crm114` already exists with mismatched values; no statically reserved UID like 550.
- Groups: create a dedicated `crm114` primary group for isolation, but keep secondary membership minimal (e.g., continue relying on `staff` only when required) so the account stays self-contained and doesn’t inherit additional privileges.
- Operator guidance: the installer copy will reassure users that account creation is transparent and audited internally; no manual verification steps are required, and future SSH access (e.g., `ssh crm114@localhost`) will be planned separately.

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Related Research
- `docs/research/hidden-user-bootstrap.md`

## Checklist
- [x] account-spec-uid-policy — Finalize UID/GID selection, collision detection, and documentation.
- [ ] account-spec-attributes — Produce authoritative attribute/filesystem matrix (dscl keys, permissions, SecureToken stance).
- [ ] account-spec-messaging — Draft Gum/simple-mode narratives explaining the hidden account to operators.
- [ ] account-spec-docs — Update parent plan + research docs with finalized spec and acceptance criteria.

## Linked Tasks
- `account-spec-uid-policy`
- `account-spec-attributes`
- `account-spec-messaging`
- `account-spec-docs`
