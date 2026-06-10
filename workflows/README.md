# Workflow design stubs

This directory holds non-executable design stubs for reusable workflow contracts
planned in later stages.

GitHub only discovers runnable workflows from `.github/workflows/`. When Stage
06 introduces reusable workflows, the executable `workflow_call` files must live
under `.github/workflows/`; this top-level directory remains a planning and
contract location unless a later ADR changes the repository layout.

Stage 04 adds [`import-quay.yml`](import-quay.yml) as a design stub because ACR
Artifact Cache does not support `quay.io`; Stage 06 turns it into an executable
OIDC-backed `az acr import` workflow.
