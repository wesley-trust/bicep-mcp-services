# bicep-mcp-services

Infrastructure-as-code for the MCP durable function back-end. The repository provisions an Azure Functions Flex Consumption (FC1) plan, configures a PowerShell 7.4 runtime for Durable orchestrations, and wires the deployment/testing pipelines that mirror the container-services estate.

## Scope
- Deploy the resource group and a Flex Consumption plan that scales to zero by default.
- Provision the function app, storage account (managed identity only), Application Insights, and Log Analytics workspace.
- Project the function app into the delegated subnet published by `bicep-network-services` using the Flex Consumption `virtualNetworkSubnetId` configuration.
- Provide unit/integration/smoke/regression Pester suites that validate Bicep what-if output and deployed resources.
- Expose Azure DevOps deploy, test, and publish pipelines through the shared dispatcher (`pipeline-dispatcher` -> `pipeline-common`).

## Repository Layout
- `pipeline/` – Azure DevOps pipeline definitions. `mcpservices.deploy.pipeline.yml` drives end-to-end deployments, `mcpservices.test.pipeline.yml` runs the CI/Nightly test matrix, and `mcpservices.publish.pipeline.yml` handles semantic releases.
- `platform/` – Bicep modules. `resourcegroup.*` deploys the container resource group. `mcpservices.*` builds the Flex Consumption plan, function app, monitoring stack, RBAC, and exposes resource IDs required by the pipelines.
- `vars/` – Layered YAML variables (`common`, `regions/*`). These feed token replacement for Bicep parameters, pipelines, and design fixtures.
- `scripts/` – Shared PowerShell helpers (`pester_run.ps1`, `pester_review.ps1`, `release_semver.ps1`).
- `tests/` – Pester suites split into `unit`, `integration`, `smoke`, and `regression` for both the resource group and the MCP service. Design fixtures in `tests/design/**` capture expected names, tags, scale settings, and health signals per environment/region.

## Pipelines
1. `mcpservices.deploy.pipeline.yml`
   - Parameters toggle production enablement, DR invocation, environment/region skips, and action-group switches.
   - Action groups: `bicep_actions` (resource group + MCP module) and the resource/service Pester suites.
2. `mcpservices.test.pipeline.yml`
   - Triggers on feature/release branches and a nightly schedule. Runs CI-focused unit + integration suites with dynamic deployment versions, plus scheduled regression/smoke runs.
3. `mcpservices.publish.pipeline.yml`
   - Kicks on `main` to tag and publish releases via `scripts/release_semver.ps1`.

All pipelines extend `mcpservices.settings.yml`, which in turn extends the dispatcher contract. Adjust pool metadata or variable include flags there when onboarding new environments.

## Flex Consumption Implementation Notes
- Hosting plan `FC1` with `reserved: true` satisfies Linux plan requirements. `functionAppConfig.scaleAndConcurrency` exposes `maximumInstanceCount` and `instanceMemoryMB` via variables.
- Runtime is locked to PowerShell 7.4; deployment packages are pulled from a storage container using the system-assigned managed identity (`blobContainer` model). Extension bundle `[4.0.0, 5.0.0)` is enabled for Durable support.
- The storage account disables shared keys and restricts access to managed identities. RBAC assignments grant Blob/Queue/Table roles to the function app.
- VNet integration sets `siteConfig.virtualNetworkSubnetId` so the function app attaches to the delegated subnet published by `bicep-network-services`.

## Testing Strategy
- **Unit** – What-if inspection ensuring resources, SKU, runtime, and scale settings match `tests/design/.../baseline.design.json` expectations.
- **Integration** – Deploys via deployment stacks, then inspects live Azure resources for runtime, scale, identity, and monitoring configuration.
- **Regression** – Guards against unexpected what-if deltas (ensures only creates and the expected inventory).
- **Smoke** – Confirms deployed resources report `provisioningState = Succeeded`.

Run locally with:
```pwsh
pwsh -File scripts/pester_run.ps1 -PathRoot tests -Type unit -TestData @{ Name = 'mcp_services' } -ResultsFile ./TestResults/unit.xml
```
(Authenticate with Azure CLI first.)

## Naming & Variables
- `vars/common.yml` drives name composition and functional defaults (instance count, memory, runtime, identity toggles). Override per environment/region under `vars/environments/*` or `vars/regions/*` as the footprint grows.
- Tokens such as `#{{ mcpFunctionAppName }}` are replaced during pipeline execution for `.bicepparam` files, design fixtures, and scripts.

## Operational Checklist
- `az bicep build platform/resourcegroup.bicep`
- `az bicep build platform/mcpservices.bicep`
- Execute the deploy pipeline for the `dev` environment and verify the function app integrates with the delegated subnet.
- Review test pipeline outputs in `TestResults/` to confirm NUnit artefacts are emitted for every suite.
- Document behavioural changes (new parameters, action groups, dependency updates) in this README.
