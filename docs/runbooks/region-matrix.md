# Region support matrix

Stage: 04 - platform shared services

Validate regional feature support before applying a non-demo or production
platform stack.

| Capability | Required for | Validation |
|------------|--------------|------------|
| Availability Zones | AKS pools, ACR zone redundancy, Postgres HA, ACA prod profile | Confirm chosen region supports zones for every enabled SKU. |
| AKS Azure CNI Overlay + Cilium | AKS baseline | Confirm AKS supports Cilium dataplane in the region. |
| AKS private cluster DNS zone | Private API server | Confirm Stage 03 created `privatelink.<region>.azmk8s.io`. |
| Front Door Private Link origin | Ingress edge | Confirm the origin region supports Front Door Premium Private Link origins before wiring PLS. |
| ACA workload profiles + zone redundancy | ACA golden path | Confirm managed environment workload profile support for the region. |
| ACR Artifact Cache | Image supply chain | Confirm cache rule support in the registry region; use `workflows/import-quay.yml` for unsupported sources such as quay.io. |

## MVP region defaults

| Profile | Primary | Paired/DR |
|---------|---------|-----------|
| demo | swedencentral | n/a |
| nonprod | swedencentral | swedensouth |
| prod | swedencentral | swedensouth |

Update this matrix before changing `location` or `paired_location` defaults.
