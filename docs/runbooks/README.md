# Runbooks

Operational runbooks for the platform landing zone. Stage 12 expands this
catalog with incident response, restore drills, and DR procedures.

| Runbook | Purpose | Stage |
| --- | --- | --- |
| [`bootstrap.md`](bootstrap.md) | Bootstrap and secret zero onto an empty/brownfield subscription | 01 |
| [`brownfield-onboarding.md`](brownfield-onboarding.md) | Audit-only onramp for an existing tenant (discovery -> audit -> drain -> deny) | 02 |
| [`policy-exception.md`](policy-exception.md) | Time-bound policy exemption workflow (request -> approve -> apply -> audit) | 02 |
