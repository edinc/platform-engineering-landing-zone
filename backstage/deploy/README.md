# Backstage deploy

Helm chart for the Stage 09 Backstage deployment.

The chart is published to ACR by `.github/workflows/ci-backstage.yml` through the
Stage 06 `helm-publish.yml` reusable workflow. Flux consumes the published chart
from the platform ACR OCI repository and injects environment-specific values via
Terraform-managed post-build substitution.
