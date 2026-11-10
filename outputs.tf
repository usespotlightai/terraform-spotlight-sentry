output "id" {
  description = "The integration's ID."
  value       = try(spotlight_integration.this[0].id, null)
}

output "address" {
  description = "The integration's address in the workspace, as in `core/sentry`."
  value       = try(spotlight_integration.this[0].address, null)
}

output "tools" {
  description = "The integration's tools, by name, to the name a station or hook gives it by, as in `{ get-issue = \"sentry.get-issue\" }`."
  value       = try(spotlight_integration.this[0].tools, {})
}

output "webhook_url" {
  description = "The webhook URL to give in the Sentry internal integration."
  value       = var.create ? "${trimsuffix(var.spotlight_url, "/")}/api/webhooks/w/${var.workspace}/t/${var.team}/${var.integration}" : null
}

output "happenings" {
  description = "The happenings the integration raises: `created` when Sentry creates an issue, `alerted` when an issue alert fires, `resolved` and `unresolved` when an issue changes status."
  value = {
    created    = "${var.integration}.issue.created"
    alerted    = "${var.integration}.alert.triggered"
    resolved   = "${var.integration}.issue.resolved"
    unresolved = "${var.integration}.issue.unresolved"
  }
}

output "marks" {
  description = "The mark kinds the integration keeps on a task: `issue` finds the task of a Sentry issue, `short_id` and `link` are kept on it."
  value = {
    issue    = local.issue_mark
    short_id = local.short_id_mark
    link     = local.link_mark
  }
}

output "client_secret_name" {
  description = "The name of the workspace secret that holds the client secret."
  value       = var.create ? local.client_secret_name : null
}

output "auth_token_name" {
  description = "The name of the workspace secret that holds the auth token."
  value       = var.create ? local.auth_token_name : null
}
