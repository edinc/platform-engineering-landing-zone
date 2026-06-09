## Stage

- [ ] Stage 00 - Foundation and repo bootstrap
- [ ] Later stage, identified in `plan/stages/`

## Summary

Describe the meaningful change and the stage acceptance criteria it supports.

## Validation

- [ ] `make lint`
- [ ] `make validate`
- [ ] `make policy-test-rego`
- [ ] `make policy-test-kyverno`
- [ ] Other:

## Security and operations

- [ ] No secrets, kubeconfigs, private keys, generated state, or tenant-specific
      credentials are committed.
- [ ] ADRs or runbooks were added/updated when the change introduced an
      architectural decision or operational procedure.
