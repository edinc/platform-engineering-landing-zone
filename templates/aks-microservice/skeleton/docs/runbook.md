# Runbook

## Health check

```bash
kubectl -n ${{ values.namespace }} get deploy,po,svc -l app.kubernetes.io/name=${{ values.componentId }}
kubectl -n ${{ values.namespace }} port-forward svc/${{ values.componentId }} 8080:${{ values.port }}
curl -fsS http://localhost:8080/healthz
```

## Alerts

SLO burn-rate alerts page `${{ values.onCallRotationId }}` and include this
runbook URL. Check the Grafana dashboard for request rate, latency, and 5xx
ratio before restarting pods.

## Workload identity

Namespace vending creates the managed identity and federated credential for
`${{ values.serviceAccountName }}` and the namespace-scoped Helm impersonation
service account `helm-${{ values.serviceAccountName }}`. Keep
`serviceAccount.create` disabled unless platform vending changes the ownership
contract. Flux source-controller uses the platform source identity for private
ACR chart reads; workload identity for `${{ values.serviceAccountName }}` is for
the running workload, not the `OCIRepository` source.
