# Complete Sentry integration

A Sentry integration on the `core` team of the `acme` workspace that creates its two secrets, opens a task at the `triage` station of the delivery lines when an issue alert fires, and marks the issue resolved in the next release when its task finishes. A second instance shows `create = false`, which creates nothing.

## Usage

Prepare the Sentry internal integration first (see [Prepare Sentry](../../README.md#prepare-sentry)), then:

```bash
terraform init
terraform plan
terraform apply
```

Give the `webhook_url` output as the webhook URL of the internal integration.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1.0-rc.4 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_sentry"></a> [sentry](#module\_sentry) | ../.. | n/a |
| <a name="module_sentry_disabled"></a> [sentry\_disabled](#module\_sentry\_disabled) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_sentry_auth_token"></a> [sentry\_auth\_token](#input\_sentry\_auth\_token) | An auth token of the Sentry internal integration. | `string` | n/a | yes |
| <a name="input_sentry_client_secret"></a> [sentry\_client\_secret](#input\_sentry\_client\_secret) | The client secret of the Sentry internal integration. | `string` | n/a | yes |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The Spotlight the integration is created in. | `string` | `"https://app.usespotlight.ai"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The webhook URL to give in the Sentry internal integration. |
<!-- END_TF_DOCS -->
