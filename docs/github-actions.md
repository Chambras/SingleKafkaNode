# GitHub Actions deployment

The [Terraform workflow](../.github/workflows/terraform.yml) supports:

| Trigger | Result |
| --- | --- |
| Push to `main`, including a merged pull request | Plan and apply |
| Actions > Terraform > Run workflow > `apply` | Create or update the infrastructure |
| Actions > Terraform > Run workflow > `destroy` | Plan and destroy, after workspace-name confirmation |

Manual runs must select `main`. No pull-request event receives deployment credentials. All operations share a concurrency group with `cancel-in-progress: false`, and Terraform also locks the HCP state. GitHub can replace an older pending run with a newer one; this is not a FIFO deployment queue.

Automation is disabled until the repository variable `TERRAFORM_AUTOMATION_ENABLED` is set to `true`. Complete the setup and state migration below before enabling it.

## Authentication model

Terraform executes on the GitHub Actions runner. **HCP Terraform stores and locks state only**, using a workspace in **Local** execution mode. Workspace variables and variable sets in HCP are not evaluated in this mode; configure inputs in GitHub instead.

- **Azure:** use a Microsoft Entra service principal with a client secret stored in GitHub Secrets. The workflow passes `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` to the AzureRM provider, following the same pattern as [HashiTalks2026](https://github.com/Chambras/HashiTalks2026/blob/main/.github/workflows/terraform.yml). No OIDC federation, `id-token` permission, `az login`, or `azure/login` action is needed.
- **HCP Terraform:** store an HCP Terraform API token as the GitHub environment secret `TF_API_TOKEN`. The workflow exposes it as `TF_TOKEN_app_terraform_io`, which Terraform recognizes automatically. Prefer a team token restricted to this workspace, with permission to read/write state and lock/unlock the workspace. A dedicated automation user's token is an alternative when team tokens are unavailable. Avoid organization tokens and broad personal administrator tokens. Rotate the token and set an expiry where supported.
- Client, tenant, and subscription IDs are identifiers, not passwords, but this workflow keeps all four `ARM_*` settings in GitHub Secrets to match the existing project. Environment variables are the delivery mechanism; GitHub Secrets is the storage mechanism for credentials. HCP token authentication through `TF_TOKEN_app_terraform_io` serves the same purpose as HashiTalks2026's `cli_config_credentials_token` setup input.

OIDC is an optional alternative that avoids storing a long-lived Azure secret. With this client-secret approach, set an expiry, rotate the secret before it expires, and restrict the service principal's permissions. If you later move execution into HCP, configure Azure credentials there and update the workflow: GitHub environment variables are not forwarded to HCP remote workers. A generic HCP platform service-principal credential is not a substitute for the HCP Terraform API token used here.

## 1. Create the GitHub environment and Azure identity

1. Create a GitHub environment named **`terraform`** under Settings > Environments. Restrict deployment branches to `main` and protect `main` with reviewed pull requests.
2. Optionally require environment reviewers. This adds approval before every deployment, including push-triggered applies; omit reviewers for unattended deployment. Approval is before the job, not a separate review of its generated plan. Protect changes to the workflow as carefully as application code.
3. In Microsoft Entra ID, create an app registration/service principal for this repository, or use an existing one authorized for this stack. A separate identity keeps permissions and credential rotation independent from other projects. Record its application (client) ID and directory (tenant) ID.
4. On that app, open Certificates & secrets > Client secrets > New client secret. Set an expiry and store the secret **Value**, not its Secret ID, directly as GitHub secret `ARM_CLIENT_SECRET`. Do not paste it into source files, logs, or chat.
5. Grant the service principal the Azure permissions needed by this stack. Subscription-scoped **Contributor** is a practical starting point because this project creates its own resource group and the provider may register resource providers. For stricter least privilege, use a custom role and pre-register the required resource providers. Do not grant Owner merely for Terraform. Resource-group-only Contributor cannot create this project's resource group.

The job grants only `contents: read` for repository access. It disables Azure CLI authentication so a self-hosted runner's existing login is not silently used instead.

## 2. Create the HCP workspace

1. In organization **`chambras`**, use the CLI-driven workspace **`SingleKafKaNode`** in project **`SWIM`**, matching the cloud block in [main.tf](../main.tf). Create the workspace in that project if it does not exist.
2. Set Settings > General > Execution Mode to **Local**, explicitly rather than inheriting a project default. Set the workspace's Terraform version to `1.16.2`, matching the workflow and the minimum in [main.tf](../main.tf).
3. Do not also enable HCP VCS-triggered deployment for this stack. GitHub Actions owns deployment triggers.
4. Create the API token described above. Store it directly in GitHub Secrets, never in a Terraform input file or a commit.

The workflow assumes the workspace is already configured for Local execution mode and does not check it through the HCP API. Ensure the token has the required workspace access within `SWIM`.

Organization and workspace values are set directly in the workflow; the workspace name is also used for destroy confirmation. You do not need GitHub Variables named `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE`, or `TF_CLOUD_PROJECT`. If you change the target later, update both the cloud block and the workflow's organization/workspace values together. Changing the project does not change the workspace's execution mode.

## 3. Runner and storage access

The workflow uses GitHub-hosted **`ubuntu-latest`** runners. No self-hosted runner registration or `TERRAFORM_RUNNER_LABELS` variable is needed. The runner image provides the shell and standard utilities, and the workflow installs the specified Terraform version.

Both storage accounts in [storage.tf](../storage.tf) default-deny network access. Managing the ADLS filesystem requires storage data-plane access during plan, apply, and destroy. Valid Azure credentials alone are not sufficient, and the `AzureServices` bypass does not allow arbitrary Actions runners.

**Network limitation:** standard `ubuntu-latest` runners have changing outbound IPs and may be blocked by these storage firewalls. This workflow does not add runner IPs to the allowlist or relax the firewall rules. Switching the runner does not resolve storage access; a successful Azure login does not guarantee a successful deployment.

If storage operations fail with network-access errors, establish an authorized network path before retrying. Options include changing `runs-on` to a runner with supported static egress or private-network access and configuring the corresponding storage rules. For existing accounts, access is needed before the first refresh, including for destroy. Do not open storage to the internet just to accommodate hosted runners.

## 4. Configure GitHub Secrets and Variables

Under the **`terraform` environment**, add:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `TF_API_TOKEN` | HCP Terraform API token |
| Secret | `ARM_CLIENT_ID` | Entra application/client ID |
| Secret | `ARM_CLIENT_SECRET` | Entra client secret Value, not Secret ID |
| Secret | `ARM_TENANT_ID` | Entra directory/tenant ID |
| Secret | `ARM_SUBSCRIPTION_ID` | Target Azure subscription ID |
| Variable | `VM_SSH_PUBLIC_KEY` | Contents of the existing VM SSH **public** key, not a path or private key |

Repository-level Secrets with these names also work, as in HashiTalks2026; environment-level Secrets with the same names take precedence. The workflow still references the `terraform` environment. Secrets in another repository are not automatically available here. The old `AZURE_*` Variables are no longer used.

The workflow uses the defaults in [variables.tf](../variables.tf), except for `sshKeyPath`: it writes `VM_SSH_PUBLIC_KEY` to a temporary file and passes that path on the command line. The public key is still required, including for destroy. Never upload the VM's private SSH key to this workflow. `TFVARS_JSON` is no longer used and can be removed from GitHub Variables.

Review the defaults before enabling automation, especially `sourceIPs` and the globally unique `storageAccountName`. The ADLS account adds `adsl` to the storage name, so use at most 20 lowercase alphanumeric characters for the base name.

When adopting an existing deployment, preserve **all existing non-default inputs and the original public key**. Removing overrides can change or replace resources, including the VM. For this single-environment project, put the intended non-sensitive values in the defaults, or explicitly map individual GitHub Variables to `TF_VAR_<name>` entries in the workflow's `env` block. GitHub Variables are not automatically Terraform inputs. Your ignored local variable files are not uploaded to the runner, and HCP workspace variables are not evaluated in Local mode. Supply any sensitive overrides through Secrets and mark the corresponding Terraform variables sensitive.

Under **repository-level** Settings > Secrets and variables > Actions > Variables, add:

| Name | Value |
| --- | --- |
| `TERRAFORM_AUTOMATION_ENABLED` | Leave absent or `false` until migration is complete, then set to `true` |

This variable must be repository-level because GitHub evaluates job eligibility before loading environment-level variables. The old `TERRAFORM_RUNNER_LABELS` variable is no longer used and can be removed.

## 5. Migrate existing local state before enabling Actions

If this project has already been applied locally, do **not** let Actions start with an empty HCP state. That can cause duplicate creation attempts and leaves destroy unable to find the existing resources.

Stop other Terraform operations. Back up the local state securely outside the repository, then run these commands yourself from the existing initialized checkout that owns the state:

```bash
terraform login
unset TF_CLOUD_ORGANIZATION TF_WORKSPACE TF_CLOUD_PROJECT
terraform init
terraform state list
```

The cloud block supplies the organization, project, and workspace; clearing old exports avoids a conflicting workspace selection. When switching from local state to the cloud configuration, `terraform init` prompts to migrate the existing local state. Review and confirm the migration interactively. Verify the expected resource addresses with `terraform state list` and confirm the state version in HCP. Do not commit state, backups, tokens, or saved plans. The workflow does not migrate or overwrite local state on your behalf.

If the state already belongs to `chambras/SingleKafKaNode`, no state move is needed just because the same target is now explicit in configuration. If it belongs to a different HCP workspace, stop and plan that state migration separately before enabling Actions. Switching Azure authentication alone does not move state or replace resources.

From your authorized workstation, run `terraform plan` with your original inputs and Azure login and resolve unexpected differences before enabling automation. For a brand-new deployment with no existing state, no migration is needed.

## 6. Run and destroy

Set the repository variable `TERRAFORM_AUTOMATION_ENABLED=true`. This does not itself trigger a deployment; the next push to `main` will, or you can immediately use a manual run.

- **Create/update:** Actions > Terraform > Run workflow > branch `main` > operation `apply`.
- **Destroy:** the same page, operation `destroy`, and enter **`SingleKafKaNode`** in `confirm_destroy`. This permanently deletes the stack's resources, including storage data. It leaves the HCP workspace and its state history intact.

Each run checks formatting, initializes with the committed provider lock file, validates, saves an apply or destroy plan, and applies exactly that plan. Applying a saved plan does not prompt again. The saved plan and temporary SSH public-key file stay on the runner and are removed by an `always()` cleanup step; they are not uploaded as artifacts. Treat state, plan output, and workflow logs as potentially sensitive and restrict access. Cleanup cannot be guaranteed if the runner is forcibly terminated; use ephemeral runners or appropriate disk cleanup policies.

A later push to `main` after destroy will recreate the infrastructure. To keep it down, set `TERRAFORM_AUTOMATION_ENABLED=false` after destruction and check for queued runs. Avoid concurrent pushes while destroying. Do not cancel a running apply/destroy unless necessary; investigate interrupted operations before unlocking state or retrying.

Local CLI operations also use HCP state. The cloud block selects the target without organization/workspace exports. Authenticate using `terraform login`, and retain your local `terraform.tfvars` and Azure login for local runs. GitHub Secrets are only injected during Actions runs.

## References

- [AzureRM service principal client-secret authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)
- [Connect the Terraform CLI to HCP Terraform and migrate state](https://developer.hashicorp.com/terraform/cli/cloud/settings)
- [HCP Terraform workspace execution modes](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings#execution-mode)
