# Security Policy

The Azure Platform Engineering Landing Zone ships secure-by-default patterns, so
we treat security reports seriously and want to make them easy to file.

## Supported scope

This repository is platform **code and documentation**: Terraform, reusable
GitHub Actions workflows, Kubernetes/Flux manifests, policy bundles, Backstage
app and templates, and scripts. Security reports are in scope when they concern:

- A vulnerability or insecure default in this repository's code, workflows,
  policies, or templates.
- Guidance in these docs that would lead an operator to deploy an insecure
  configuration.

The `main` branch is the only supported version. Findings are addressed on
`main` and flow forward; there are no separately maintained release branches.

Out of scope: vulnerabilities in upstream Azure services or third-party
dependencies themselves (report those to the relevant vendor), and findings that
require already-compromised privileged credentials.

## Reporting a vulnerability

**Please do not open a public issue, pull request, or discussion for a security
report.**

Use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab.
2. Choose **Report a vulnerability** to open a private advisory.

Include, where possible:

- A description of the issue and its impact.
- Steps to reproduce, affected files/paths, and any proof-of-concept.
- The profile (`demo`, `nonprod`, `prod`) or configuration where it applies.

If private reporting is unavailable to you, contact the repository owner
([@edinc](https://github.com/edinc)) to arrange a private channel.

## What to expect

- **Acknowledgement** within 5 business days.
- A **triage assessment** and severity rating, and a request for any missing
  detail.
- A **remediation plan** with a target timeline proportional to severity, and
  coordinated disclosure once a fix is available.

Please give us a reasonable opportunity to remediate before any public
disclosure. We will credit reporters who wish to be acknowledged.

## Handling sensitive data

Never include real secrets, tenant IDs, subscription IDs, private keys, or
generated kubeconfigs in a report. Redact identifiers and share the minimum
needed to reproduce. The same rule applies to all contributions — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).
