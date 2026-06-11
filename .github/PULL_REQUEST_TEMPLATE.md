## Stage

- Stage: <!-- e.g., Stage 05 - Environment and subscription vending -->
- Stage plan: <!-- e.g., `plan/stages/stage-05-vending.md` -->

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
