# Cost allocator module

Stage 08 uses this module to run a nightly Python Azure Function that reads the
existing ALZ-owned Cost Management export container and publishes team/product
showback CSVs to a private output container.

The module intentionally uses managed identity for storage data-plane access:
the Function identity receives read access to the source export container and
write access to the showback container. Real Function packages are supplied via
`function_package_path`; the reference source lives in `function_app/`.

The default service plan is EP1 with three zone-balanced workers so production
profiles have failover capacity by default. Demo profiles can override the SKU
and worker count as an explicit cost exception.

The platform stack requires `cost_allocator_function_package_path` when
`enable_cost_allocator = true`. Build the reference app into a ZIP and pass that
path. The secure default keeps public network access disabled and requires
Function VNet integration plus blob, queue, and table private endpoints.
