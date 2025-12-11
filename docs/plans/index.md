# Plans Index

- [x] installer-detection — Guard install.sh to run only on supported Apple Silicon macOS (`docs/plans/installer-detection.md`)
- [x] gum-powered-installer — Adopt Gum to deliver a friendly, transparent installer experience (`docs/plans/gum-powered-installer.md`)
- [ ] hidden-user-bootstrap — Provision hidden crm114 service account with concealed home directory (`docs/plans/hidden-user-bootstrap.md`)
- [x] installer-debug-flag — Provide a --debug flag and verbose tracing so humans can share actionable installer diagnostics (`docs/plans/installer-debug-flag.md`)
- [x] hidden-user-account-spec — Define UID/GID, attributes, filesystem state, and messaging for the hidden `crm114` account (`docs/plans/hidden-user-account-spec.md`)
- [ ] tests-path-removal — Remove references to the deprecated legacy tests directory and add guardrails (`docs/plans/tests-path-removal.md`)

## Next Step

- [ ] tests-path-scrub (plan: tests-path-removal) — Remove all legacy installer test path references and update guidance so operators follow valid instructions.
- [ ] hidden-user-idempotence (plan: hidden-user-bootstrap) — Build verification/drift-repair logic and add scripted tests so operators can confirm the hidden account state quickly.
