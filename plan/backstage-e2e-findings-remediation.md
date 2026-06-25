# Backstage E2E findings and remediation plan

## Current outcome

The deployed public Backstage portal is reachable and the previous startup
crashes are resolved, but the app is not yet fully end-to-end healthy.

Validated public URL:

```text
https://pe-demo-sec-eb64p4-backstage.swedencentral.cloudapp.azure.com
```

What works:

1. Public endpoint returns HTTP `200`.
2. The app shell loads after sign-in.
3. The Cost Insights `API_FACTORY_CONFLICT` startup failure is gone.
4. The Notifications `plugin.notifications.service` provider failure is gone.
5. Catalog loads and shows seven components.
6. API Explorer loads.
7. Cost Insights loads.
8. Notifications page loads.
9. Register Existing Component loads.

## Findings

| Area | Result | Evidence |
| --- | --- | --- |
| Home route `/` | Fails | Renders Backstage 404 page. |
| Settings route `/settings` | Fails | Renders Backstage 404 page. |
| Kubernetes route `/kubernetes` | Fails | Runtime error: `Entity context is not available`. |
| Search modal | Fails | Runtime error: `No implementation available for apiRef{plugin.search.queryservice}`. |
| Sidebar | Degraded | `Notifications` appears twice. |
| Create templates | Degraded / needs decision | Create page loads, but reports no templates found. Backstage config currently registers template locations, so either template visibility is now part of the Stage 09 MVP and this is a defect, or the Stage 09 registration is premature and Create content should be explicitly treated as Stage 10/11 scope. |
| Docs | Degraded / needs triage | Docs page loads, but reports no documents. This may reflect missing TechDocs annotations/generated docs rather than a runtime failure. |

## Current blocker

Some remaining route/provider fixes require editing the Backstage frontend app
wiring file:

```text
backstage/app/packages/app/src/App.tsx
```

That path is currently blocked by the organization content exclusion policy in
this Copilot session. The policy must be changed by an organization/admin owner
before the agent can safely edit or inspect that file; the agent must not bypass
the policy with alternate tools or infer the restricted file contents.

Not every finding is blocked by this policy. The duplicate Notifications nav
entry and Kubernetes global-page behavior can likely be addressed in
non-restricted configuration/nav files. Search, Settings, and the root route may
also be possible through non-restricted frontend modules/config; if those paths
are not sufficient, the restricted app wiring file will need to be unblocked.

## Remediation plan

### 1. Attempt non-restricted remediation first

Before waiting on the content-policy change, attempt fixes in files that are not
blocked:

1. In the custom sidebar/nav module, hide the automatically discovered
   Notifications page entry while keeping the notification-aware sidebar item.
2. Disable the standalone Kubernetes page extension through app configuration if
   supported by the current Backstage frontend system. Hiding only the nav entry
   is not enough because direct hits to `/kubernetes` currently throw an entity
   context error.
3. Check whether a non-restricted frontend module can register the Search query
   API provider, User Settings route, and root redirect. If this is not possible,
   those fixes must wait for `App.tsx`.

### 2. Unblock the frontend app wiring file if still required

Update the organization Copilot content exclusion policy so this repo/path is
available to the agent:

```text
backstage/app/packages/app/src/App.tsx
```

After the policy changes, restart or refresh the Copilot session so the updated
policy is applied.

### 3. Fix findings that do not require the restricted app wiring file

These should be implemented first because they are not expected to require
`App.tsx`:

1. Keep a single Notifications sidebar entry. Prefer the notification-aware
   sidebar item and hide the automatically discovered Notifications page entry.
2. Disable or remove the global Kubernetes page route through app configuration,
   not only its sidebar nav entry. The current global route is mounted without an
   entity context.
   Kubernetes should remain entity-scoped for the Stage 09 MVP. Any future global
   Kubernetes view should be introduced only after tenancy and RBAC semantics make
   it intentional.

### 4. Fix missing frontend app route/provider wiring

Once `App.tsx` is accessible:

1. Add a valid root route for `/`, preferably redirecting to `/catalog` for the
   Stage 09 MVP.
2. Register the User Settings frontend plugin/provider so `/settings` is a real
   route.
3. Register the Search frontend plugin/provider so the search modal has an
   implementation for `plugin.search.queryservice`.

### 5. Decide and investigate catalog content gaps

The Create and Docs pages load, so these are content/data gaps rather than app
startup failures.

1. Decide whether Create templates are expected to be visible in Stage 09.
   Stage 10 owns onboarding templates and Stage 11 owns golden paths, but this
   repository currently registers several templates in Backstage config.
2. If templates are in Stage 09 scope, treat "no templates found" as a defect and
   first verify URL resolution for the configured GitHub template locations:
   branch availability, GitHub App repository read access, and config
   substitution for the repository owner/name.
3. Verify the signed-in tester's Backstage identity, group membership, and
   Scaffolder template-read authorization before treating "no templates found" as
   only a catalog ingestion problem.
4. Confirm Backstage can ingest all expected Software Templates from:
   - `templates/onboard-team/template.yaml`
   - `templates/request-egress-exception/template.yaml`
   - `templates/aks-workload-namespace/template.yaml`
   - `templates/aks-microservice/template.yaml`
   - `templates/aca-service/template.yaml`
5. Check catalog processor logs for template ingestion errors.
6. Decide whether Docs content is expected in Stage 09. If yes, confirm expected
   catalog entities advertise TechDocs with
   `backstage.io/techdocs-ref` annotations.
7. Confirm TechDocs publishing has run for expected components, and that the
   TechDocs storage container contains generated docs.

## Acceptance criteria

1. `/` no longer renders a 404 and lands on an intended default page.
2. `/settings` loads the signed-in user settings page.
3. Clicking Search opens a working search UI without
   `plugin.search.queryservice` errors.
4. `/kubernetes` no longer throws `Entity context is not available`; the global
   route is disabled/removed unless an intentional global view is designed.
5. Sidebar contains exactly one Notifications entry.
6. Catalog, APIs, Cost Insights, Notifications, Register Existing Component,
   Create, Docs, and Search load without browser console errors. Empty Create or
   Docs content is acceptable only if explicitly confirmed as out-of-scope for
   Stage 09.
7. Stage 09 validation includes static guardrails for the root route,
   settings/search providers, Kubernetes route handling, single Notifications nav
   behavior, and expected Backstage app feature registrations.

## Validation checklist

Run after remediation is implemented and deployed:

1. `python3 scripts/backstage/validate_stage09_backstage.py`
2. `cd backstage/app && yarn tsc --pretty false`
3. `cd backstage/app && yarn workspace app test --runInBand --watch=false src/App.test.tsx`
4. `cd backstage/app && yarn workspace app build`
5. Live Playwright route smoke test for:
   - `/`
   - `/catalog`
   - `/create`
   - `/cost-insights`
   - `/api-docs`
   - `/docs`
   - `/kubernetes`
   - `/notifications`
   - `/catalog-import`
   - `/settings`
6. Live Playwright interaction test for the sidebar Search button. Search must
   open without `plugin.search.queryservice` errors or a React error boundary.
7. Browser console check: no `Error in app`, `NotImplementedError`, or
   route-level React error boundaries on the above routes.

## Stage alignment

This remediation belongs primarily to Stage 09 Backstage MVP. The Kubernetes
entity-level view is Stage 09 scope, but the current global route is not a Stage
09 requirement and should remain disabled unless a later stage deliberately adds
a global cluster view with clear tenancy and RBAC semantics.

Create-template and Docs content gaps overlap with Stage 10 and Stage 11. Because
the current Backstage config registers template locations, the project must
explicitly decide whether those templates/docs are in Stage 09 scope. If yes,
empty Create/Docs states are defects; if no, the registration should be deferred
or documented as early wiring that is not part of the Stage 09 acceptance gate.
