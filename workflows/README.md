# Workflow design stubs

This directory holds lightweight contract records for reusable workflow surfaces.

GitHub only discovers runnable reusable workflows from `.github/workflows/`.
Stage 06 therefore keeps executable `workflow_call` files under
`.github/workflows/`, while this top-level directory records the contract
lineage and intended executable location.

Stage 04 added [`import-quay.yml`](import-quay.yml) as a design stub because ACR
Artifact Cache does not support `quay.io`; Stage 06 turns it into an executable
OIDC-backed `az acr import` reusable workflow.
