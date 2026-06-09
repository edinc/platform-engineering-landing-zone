# Workflow design stubs

This directory holds non-executable design stubs for reusable workflow contracts
planned in later stages.

GitHub only discovers runnable workflows from `.github/workflows/`. When Stage
06 introduces reusable workflows, the executable `workflow_call` files must live
under `.github/workflows/`; this top-level directory remains a planning and
contract location unless a later ADR changes the repository layout.
