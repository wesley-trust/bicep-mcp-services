# Agent Handbook

## Mission Overview
- **Repository scope:** Azure Functions Flex Consumption (PowerShell Durable) deployment for MCP services. Includes the pipelines, variables, scripts, and tests required to manage the infrastructure lifecycle.
- **Primary pipeline files:** `pipeline/mcpservices.deploy.pipeline.yml` exposes Azure DevOps parameters, `pipeline/mcpservices.settings.yml` links to the dispatcher, `pipeline/mcpservices.test.pipeline.yml` provides CI/nightly coverage, and `pipeline/mcpservices.publish.pipeline.yml` runs semantic releases.
- **Action groups:** `bicep_actions` (resource group + MCP module), `bicep_tests_resource_group`, and `bicep_tests_mcp_services` (Pester via Azure CLI with NUnit output saved to `TestResults/<actionGroup>_<action>.xml`).
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which pins `wesley-trust/pipeline-common`. Consult those repos when adjusting schema, variable layering, or environment metadata.

## Repository Layout
- `pipeline/` – Deployment, test, and release pipelines plus dispatcher configuration.
- `platform/` – Bicep modules (`resourcegroup.*`, `mcpservices.*`, and the RBAC helper under `platform/modules`).
- `vars/` – Layered variables (`common`, `regions/*`). Extend with environment-specific files when multiple environments onboard.
- `scripts/` – PowerShell helpers (`pester_run.ps1`, `pester_review.ps1`, `release_semver.ps1`).
- `tests/` – Pester suites (`unit`, `integration`, `smoke`, `regression`) for resource group and MCP service, plus design fixtures in `tests/design/**`.

## Pipeline Execution Flow
1. `mcpservices.deploy.pipeline.yml` declares runtime toggles (production enablement, DR, environment/region skips, action/test switches) then extends `mcpservices.settings.yml`.
2. `mcpservices.settings.yml` references the dispatcher (`/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`).
3. The dispatcher merges defaults, attaches variables, and forwards configuration to `pipeline-common/templates/main.yml`.
4. `pipeline-common` runs initialise, validation, optional review, and deploy stages while executing the configured action groups.

## Customisation Points
- Add modules or scripts via new entries in `mcpservices.deploy.pipeline.yml` or the CI pipeline. Respect the expected schema (`type`, `scope`, `templatePath`, etc.).
- Override variable layers or environment metadata in `mcpservices.settings.yml` (e.g., include environment-specific YAML, adjust pools/approvals).
- Extend `platform/mcpservices.bicep` when introducing new resources (additional storage, key vault, etc.) and update tests & design fixtures accordingly.
- Expand design fixtures under `tests/design` to surface new resources/health checks so smoke and regression suites can assert them.

## Testing & Validation
- `scripts/pester_run.ps1` installs Az + Pester (if needed), authenticates using the federated token supplied by Azure CLI, and executes the requested suite with NUnit output.
- Unit/regression suites consume Bicep what-if output, integration/smoke suites inspect deployed resources via Deployment Stacks + `Get-AzResource`.
- CI action groups enable `variableOverridesEnabled` with `dynamicDeploymentVersionEnabled: true` so parallel runs don't clobber each other.
- Use `az bicep build platform/resourcegroup.bicep` and `platform/mcpservices.bicep` locally before raising PRs.

## Operational Notes
- Record behavioural changes (new parameters, action groups, dependency upgrades) in `README.md`.
- Coordinate dispatcher updates when adjusting shared defaults (service connections, approvals, pools) to keep consumers aligned.
- Preview pipeline YAML through `pipeline-common/tests` before merging significant changes.

## References
- `pipeline-common/AGENTS.md` – pipeline stages and configuration schema.
- `pipeline-common/docs/CONFIGURE.md` – exhaustive parameter reference.
- `pipeline-dispatcher/AGENTS.md` – dispatcher contract and merge order.
