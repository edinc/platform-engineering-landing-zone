# ADR-0056: Dedicated Backstage GitHub App

- Status: accepted
- Date: 2026-06-25
- Stage: Stage 09 - Backstage MVP

## Context

Backstage needs a GitHub App to read catalog locations and software templates
from the platform repository, run org/repo discovery, and execute scaffolder
actions (repo create/push, pull requests, workflows). The platform already has a
separate Terraform-managed `platform-vending-bot` GitHub App
(`infrastructure/terraform/github-app/`) used for cross-repo vending writes into
`platform-cluster-state` and the landing-zone repo.

GitHub App registrations cannot be created through Terraform or the REST API
alone — the App Manifest flow requires a one-time in-browser approval — and their
credentials (private key, client secret) must never enter Terraform state.

A deployment incident confirmed the failure mode of leaving this unprovisioned:
the `backstage-github-app-*` Key Vault secrets held placeholders (App ID `1`,
client ID `Iv1.placeholderclientid`), so GitHub rejected the App JWT with
`Integration not found` and the Backstage catalog could not read the private-repo
template URLs (the Create page showed no templates).

## Decision

Use a dedicated GitHub App for the Backstage portal, separate from
`platform-vending-bot`:

- Its credentials live in the platform Key Vault as `backstage-github-app-id`,
  `-client-id`, `-client-secret`, `-webhook-secret`, and `-private-key`.
- Terraform manages only the Key Vault role assignments for those secret names
  (`infrastructure/terraform/platform/key-vault.tf`); the secret **values** are
  seeded out-of-band so they never enter Terraform state.
- The app is created via the App Manifest flow
  (`scripts/backstage/create-backstage-github-app.mjs`) with scaffolder-capable
  repository permissions (Administration, Contents, Pull requests, Issues,
  Webhooks, Workflows, Pages read/write; Metadata read) and installed on the
  platform repositories. Read-only Contents + Metadata is sufficient for Stage 09
  template visibility; the write permissions enable Stage 10/11 scaffolding.
- Provisioning, rotation, and the `Integration not found` recovery path are
  documented in `docs/runbooks/backstage-ops.md`.

## Consequences

- Clear ownership boundary: `platform-vending-bot` owns cross-repo vending
  writes; the Backstage app owns portal catalog ingestion and scaffolder
  execution. Neither app is over-scoped to cover the other's blast radius.
- Two GitHub Apps must be managed and rotated. Accepted as the cost of keeping
  identity and least-privilege boundaries clean.
- App creation and secret seeding remain documented manual operator steps,
  consistent with the runbook guidance to seed Backstage runtime secrets from a
  VNet-connected session before enabling `enable_backstage`.
- A Stage 09 validation guardrail and a runbook troubleshooting entry guard
  against silently reintroducing placeholder credentials.
