# Kyverno policies

Kubernetes admission policies live here and are tested with `kyverno test`.

Stage 00 includes a small fixture that validates standard Kubernetes app labels
on Pods so the Kyverno test harness is executable before deployable manifests
exist.
