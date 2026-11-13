# terraform-spotlight-sentry

A Spotlight integration for a Sentry internal integration. When an issue alert fires, or when Sentry creates an issue, a task opens on the team's lines with the issue's title, place and link. Later deliveries for the same issue, such as a resolve or a regression, go to that task. Agents get tools to read the issue and its latest event, with the stack trace. When the task finishes, the module can resolve the issue in Sentry.

The module creates a `spotlight_integration` and, unless you keep them yourself, the two `spotlight_secret`s it uses: the internal integration's client secret, which verifies that deliveries come from Sentry, and its auth token, bound to the host of `sentry_url`.

```
Sentry ──webhook (signed with the client secret)──▶ webhook_url
                                                      │ verify
                                                      ▼
                         event_alert.triggered → opens a task on the lines whose role is line_role
                         issue.created         → (or this, with opens_on = "issue")
                         issue.resolved        → a note on the issue's task
                         issue.unresolved      → a note on the issue's task
                                                      │
agent ──get-issue, get-latest-event (auth token)──────┤ /api/0/organizations/<organization>/issues/<id>/
task finishes ──PUT status (auth token)───────────────┘ only with resolve_on_finish
```

## Version constraints

Terraform 1.11 is the floor because `value_wo` on `spotlight_secret` is a **write-only** attribute: Terraform sends the secret to Spotlight but never stores it in the plan or the state. `client_secret` and `auth_token` are ephemeral variables for the same reason. Spotlight only takes new values when `secret_version` changes.

The module needs the Spotlight provider 0.1.0-rc.4 or later, the first release that calls the control plane's `/api/v1` resource API.

The module and the provider are release candidates. Terraform selects a release candidate only for an exact version, such as `version = "0.1.0-rc.4"`. It skips release candidates for `>=` and `~>`. Thus, pin the module and the provider to exact versions, as in [Usage](#usage).

Spotlight checks the integration's definition when you plan and apply, not the provider. If the definition format changes in a Spotlight release, update the module to the release that follows it.

## Usage

```hcl
terraform {
  required_providers {
    spotlight = {
      source  = "usespotlightai/spotlight"
      version = "0.1.0-rc.4"
    }
  }
}

module "sentry" {
  source  = "usespotlightai/sentry/spotlight"
  version = "0.1.0-rc.2" # x-release-please-version

  workspace    = "acme"
  team         = "core"
  organization = "acme"

  client_secret = var.sentry_client_secret
  auth_token    = var.sentry_auth_token
}

output "sentry_webhook_url" {
  value = module.sentry.webhook_url
}
```

### Prepare Sentry

1. In Sentry, open Settings › Developer Settings › Custom Integrations, and create an internal integration.
2. Give it the permission Issue & Event: Read. To use `resolve_on_finish`, give Issue & Event: Read & Write.
3. Turn on Alert Rule Action, so that alert rules can send to it. Under Webhooks, subscribe to `issue`.
4. Copy the client secret into `client_secret`, and the integration's auth token into `auth_token`.
5. Run `terraform apply`, give `webhook_url` as the integration's webhook URL, and save.
6. In an issue alert rule, add the action "Send a notification via" the internal integration.

On a self-hosted Spotlight, set `spotlight_url` to your deployment's address so `webhook_url` is right. For Sentry's EU region or a self-hosted Sentry, set `sentry_url`, as in `https://de.sentry.io`. Spotlight does not follow redirects, so `sentry_url` must be the host that answers the API.

### Open tasks

By default, a task opens when an issue alert rule fires, on each line of the team whose role is `line_role`, `delivery` by default. You choose in Sentry which issues fire an alert. Set `opens_on = "issue"` to open a task for each issue Sentry creates. Set `station` to open the task at a station other than the line's first work station, as in `triage`. Set `line_role = null` to open no task: the happenings then reach only tasks that already have the issue's mark.

Each task keeps three marks: `sentry.issue`, the issue's ID, which finds the task; `sentry.short_id`, as in `FRONTEND-3K`, when Sentry created the issue; and `sentry.link`, the address of the issue or event. A second alert for the same issue goes to the same task, and opens no other.

### Read an issue from an agent

The integration gives agents two tools, `get-issue` and `get-latest-event`. `get-latest-event` returns the latest event with its stack trace, breadcrumbs and tags. Each run on a task with a `sentry.issue` mark has both tools, at every station, so an agent can follow up on the alert that opened its task. Both take the issue's ID or short ID, and without it read the task's issue.

To give the tools to a station for tasks without the mark, enable them through the `tools` output, so a plan fails if a tool is renamed or removed:

```hcl
tools = [module.sentry.tools["get-latest-event"]]
```

### Resolve the issue

Set `resolve_on_finish = "resolvedInNextRelease"` to resolve the issue in Sentry's next release when its task finishes, or `"resolved"` to resolve it at once. The auth token then needs Issue & Event: Read & Write.

### Keep the secrets yourself

To manage the secrets outside this module, for example read from AWS Secrets Manager, set `create_secrets = false` and give their names in `client_secret_name` and `auth_token_name`. Bind the auth token's secret to the host of `sentry_url` in the `authorization` header, with the prefix `Bearer `.

### Rotating the secrets

Give the new values in `client_secret` and `auth_token`, and raise `secret_version`. Terraform sends both values again.

## Conditional creation

```hcl
module "sentry" {
  source = "usespotlightai/sentry/spotlight"

  create = false
  # ...
}
```

## Examples

- [complete](examples/complete)

## Testing

```sh
terraform init -backend=false
terraform test    # tests/*.tftest.hcl, against a mocked spotlight provider
```

## Contributing

Formatting, the generated sections of every README, tflint and `terraform validate` run through [pre-commit](https://pre-commit.com), which needs [terraform-docs](https://terraform-docs.io) and [tflint](https://github.com/terraform-linters/tflint) installed:

```sh
pre-commit install
pre-commit run --all-files
```

CI runs the same hooks and the tests on every pull request. Pull requests are squash-merged, and the title becomes the commit, so the title is a Conventional Commit with the Linear issue as the scope, as in `feat(SPO-123): Add a project input`. Releases follow [semantic versioning](https://semver.org) and come from [release-please](https://github.com/googleapis/release-please): after each merge to `main` it updates one release pull request with the next version, the `version` in this README's usage example and the [CHANGELOG.md](CHANGELOG.md) entries. Merging that pull request tags the release and publishes it, and the Terraform Registry picks it up. `feat` and `fix` commits make a release. While `release-please-config.json` has `"prerelease": true`, each release is the next `-rc.N`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1.0-rc.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_spotlight"></a> [spotlight](#provider\_spotlight) | >= 0.1.0-rc.4 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [spotlight_integration.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/integration) | resource |
| [spotlight_secret.auth_token](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_secret.client](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_team.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/team) | data source |
| [spotlight_workspace.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/workspace) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_organization"></a> [organization](#input\_organization) | The slug of the Sentry organization, as in `acme`. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | The key of the team the integration belongs to, as in `core`. | `string` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | The slug of the Spotlight workspace, as in `acme`. | `string` | n/a | yes |
| <a name="input_auth_token"></a> [auth\_token](#input\_auth\_token) | An auth token of the Sentry internal integration. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_auth_token_name"></a> [auth\_token\_name](#input\_auth\_token\_name) | The name of the workspace secret that holds the auth token. | `string` | `"SENTRY_AUTH_TOKEN"` | no |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | The client secret of the Sentry internal integration, which signs its webhooks. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_client_secret_name"></a> [client\_secret\_name](#input\_client\_secret\_name) | The name of the workspace secret that holds the client secret. | `string` | `"SENTRY_CLIENT_SECRET"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create the integration and its secrets. False creates nothing. | `bool` | `true` | no |
| <a name="input_create_secrets"></a> [create\_secrets](#input\_create\_secrets) | Whether the module creates the two secrets from `client_secret` and `auth_token`. False uses the workspace secrets named `client_secret_name` and `auth_token_name`, which you keep yourself; the auth token's secret must then be bound to the host of `sentry_url` in the `authorization` header, with the prefix `Bearer `. | `bool` | `true` | no |
| <a name="input_integration"></a> [integration](#input\_integration) | The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `sentry.issue.created`. Fixed for the integration's life. | `string` | `"sentry"` | no |
| <a name="input_line_role"></a> [line\_role](#input\_line\_role) | The role of the lines that a Sentry issue opens a task on, as in `delivery`. Null opens no task: the happenings then only reach the tasks that already have the issue's mark. | `string` | `"delivery"` | no |
| <a name="input_logo"></a> [logo](#input\_logo) | The mark the web app shows for the integration, as a base64 data URI of an SVG, PNG, WebP or JPEG image or as an https address. By default, the mark of Sentry. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | What the integration is called in the web app. | `string` | `"Sentry"` | no |
| <a name="input_opens_on"></a> [opens\_on](#input\_opens\_on) | What opens a task: `alert` when an issue alert rule that sends to the integration fires, or `issue` when Sentry creates an issue. | `string` | `"alert"` | no |
| <a name="input_resolve_on_finish"></a> [resolve\_on\_finish](#input\_resolve\_on\_finish) | The status the Sentry issue gets when its task finishes: `resolved`, or `resolvedInNextRelease`. Null leaves the issue as it is. | `string` | `null` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Change it when `client_secret` or `auth_token` changes, so Terraform sends the new values to Spotlight. | `number` | `1` | no |
| <a name="input_sentry_url"></a> [sentry\_url](#input\_sentry\_url) | The address of the Sentry API, as in `https://de.sentry.io` for the EU region or the address of a self-hosted Sentry. The auth token is sent only to its host. | `string` | `"https://sentry.io"` | no |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight. | `string` | `"https://app.usespotlight.ai"` | no |
| <a name="input_station"></a> [station](#input\_station) | The key of the station a task opens at, as in `triage`. Null opens it at the line's first work station. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The integration's address in the workspace, as in `core/sentry`. |
| <a name="output_auth_token_name"></a> [auth\_token\_name](#output\_auth\_token\_name) | The name of the workspace secret that holds the auth token. |
| <a name="output_client_secret_name"></a> [client\_secret\_name](#output\_client\_secret\_name) | The name of the workspace secret that holds the client secret. |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises: `created` when Sentry creates an issue, `alerted` when an issue alert fires, `resolved` and `unresolved` when an issue changes status. |
| <a name="output_id"></a> [id](#output\_id) | The integration's ID. |
| <a name="output_marks"></a> [marks](#output\_marks) | The mark kinds the integration keeps on a task: `issue` finds the task of a Sentry issue, `short_id` and `link` are kept on it. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name, to the name a station or hook gives it by, as in `{ get-issue = "sentry.get-issue" }`. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The webhook URL to give in the Sentry internal integration. |
<!-- END_TF_DOCS -->

## License

Apache 2.0. See [LICENSE](LICENSE).
