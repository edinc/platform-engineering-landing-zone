# Backstage deploy

Helm chart for the Backstage portal deployment.

The chart is published to ACR by `.github/workflows/cd-backstage.yml` through the
`helm-publish.yml` reusable workflow. Flux consumes the published chart
from the platform ACR OCI repository and injects environment-specific values via
Terraform-managed post-build substitution.
