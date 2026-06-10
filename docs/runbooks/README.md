# Runbooks

Operational runbooks for the platform landing zone. Stage 12 expands this
catalog with incident response, restore drills, and DR procedures.

| Runbook | Purpose | Stage |
| --- | --- | --- |
| [`bootstrap.md`](bootstrap.md) | Bootstrap and secret zero onto an empty/brownfield subscription | 01 |
| [`subscription-onboarding.md`](subscription-onboarding.md) | Existing-subscription onboarding/readiness against an external ALZ | 02 |
| [`policy-exception.md`](policy-exception.md) | Time-bound policy exemption workflow (request -> approve -> apply -> audit) | 02 |
| [`egress-exception.md`](egress-exception.md) | Time-bound outbound egress exception workflow for firewall and NetworkPolicy changes | 03 |
| [`dr-matrix.md`](dr-matrix.md) | RTO/RPO matrix and DR validation handoff | 04 |
| [`aks-baseline.md`](aks-baseline.md) | AKS baseline operations, upgrades, and follow-ups | 04 |
| [`region-matrix.md`](region-matrix.md) | Regional feature support matrix for Stage 04 services | 04 |
