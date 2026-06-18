# Workflow design stubs

This directory holds lightweight contract records for reusable workflow surfaces.

GitHub only discovers runnable reusable workflows from `.github/workflows/`.
Executable `workflow_call` files live under `.github/workflows/`, while this
top-level directory records their customer-facing contract and intended
executable location.

[`import-quay.yml`](import-quay.yml) records the quay.io import contract because
ACR Artifact Cache does not support `quay.io`; the executable workflow uses OIDC
and `az acr import`.
