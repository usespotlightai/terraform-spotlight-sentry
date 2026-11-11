data "spotlight_workspace" "this" {
  count = var.create ? 1 : 0

  slug = var.workspace
}

data "spotlight_team" "this" {
  count = var.create ? 1 : 0

  workspace_id = data.spotlight_workspace.this[0].id
  key          = var.team
}

locals {
  logo = coalesce(var.logo, "data:image/svg+xml;base64,${filebase64("${path.module}/logo.svg")}")

  client_secret_name = try(spotlight_secret.client[0].name, var.client_secret_name)
  auth_token_name    = try(spotlight_secret.auth_token[0].name, var.auth_token_name)

  sentry_url  = trimsuffix(var.sentry_url, "/")
  sentry_host = regex("^https://([^/:]+)", var.sentry_url)[0]
  issues_url  = "${local.sentry_url}/api/0/organizations/${var.organization}/issues"
  auth        = { secrets = ["secret.${local.auth_token_name}"] }

  issue_mark    = "${var.integration}.issue"
  short_id_mark = "${var.integration}.short_id"
  link_mark     = "${var.integration}.link"

  resource = "headers[\"sentry-hook-resource\"]"

  issue_marks = [
    { kind = local.issue_mark, value = "$${{ body.data.issue.id }}" },
    { kind = local.short_id_mark, find = false, value = "$${{ body.data.issue.shortId }}" },
    { kind = local.link_mark, find = false, value = "$${{ body.data.issue.web_url }}" },
  ]

  opens_task = var.line_role != null

  opens_issue = merge(
    {
      lineRole    = var.line_role
      title       = "$${{ body.data.issue.title }}"
      description = "$${{ \"Sentry issue \" + body.data.issue.shortId + \" in \" + body.data.issue.project.slug + (body.data.issue.culprit != \"\" ? \", at \" + body.data.issue.culprit : \"\") + \".\\n\\n\" + body.data.issue.web_url }}"
    },
    var.station == null ? {} : { station = var.station },
  )

  opens_alert = merge(
    {
      lineRole    = var.line_role
      title       = "$${{ body.data.event.title }}"
      description = "$${{ \"The Sentry alert “\" + body.data.triggered_rule + \"” fired\" + (has(body.data.event.culprit) && body.data.event.culprit != \"\" ? \", at \" + body.data.event.culprit : \"\") + \".\\n\\n\" + body.data.event.web_url }}"
    },
    var.station == null ? {} : { station = var.station },
  )

  issue_created = merge(
    {
      happening = "${var.integration}.issue.created"
      label     = "Issue created"
      summary   = "Sentry created an issue."
      marks     = local.issue_marks
    },
    local.opens_task && var.opens_on == "issue" ? { opens = local.opens_issue } : {},
  )

  alert_triggered = merge(
    {
      happening = "${var.integration}.alert.triggered"
      label     = "Alert fired"
      summary   = "A Sentry alert fired."
      marks = [
        { kind = local.issue_mark, value = "$${{ string(body.data.event.issue_id) }}" },
        { kind = local.link_mark, find = false, value = "$${{ body.data.event.web_url }}" },
      ]
    },
    local.opens_task && var.opens_on == "alert" ? { opens = local.opens_alert } : {},
  )

  for_issue = {
    thread = "$${{ \"${local.issue_mark}\" in task.marks ? task.marks[\"${local.issue_mark}\"] : \"\" }}"
  }

  resolve_actions = var.resolve_on_finish == null ? {} : {
    resolve = {
      request = {
        method = "PUT"
        url    = "${local.issues_url}/$${{ target.thread }}/"
        auth   = local.auth
        body   = "$${{ {\"status\": \"${var.resolve_on_finish}\"} }}"
        expect = { success = "$${{ status >= 200 && status < 300 }}" }
      }
    }
  }

  resolve_on = var.resolve_on_finish == null ? {} : {
    "task.finished" = [{ action = "resolve", to = local.for_issue }]
  }

  issue_input = {
    issue = { type = "string", required = true, description = "The ID or short ID of the Sentry issue, as in 4507182346 or FRONTEND-3K." }
  }

  checked_issue = "$${{ inputs.issue.matches(\"^[A-Za-z0-9-]+$\") ? inputs.issue : \"-\" }}"
}

resource "spotlight_secret" "client" {
  count = var.create && var.create_secrets ? 1 : 0

  workspace_id     = data.spotlight_workspace.this[0].id
  name             = var.client_secret_name
  value_wo         = var.client_secret
  value_wo_version = var.secret_version
}

resource "spotlight_secret" "auth_token" {
  count = var.create && var.create_secrets ? 1 : 0

  workspace_id = data.spotlight_workspace.this[0].id
  name         = var.auth_token_name
  bindings = [
    { host = local.sentry_host, location = "header", name = "authorization", prefix = "Bearer " },
  ]
  value_wo         = var.auth_token
  value_wo_version = var.secret_version
}

resource "spotlight_integration" "this" {
  count = var.create ? 1 : 0

  team_id = data.spotlight_team.this[0].id
  definition = {
    integration = var.integration
    name        = var.name
    logo        = local.logo

    webhook = {
      verify = {
        hmac = {
          algorithm = "sha256"
          secret    = "secret.${local.client_secret_name}"
          header    = "sentry-hook-signature"
          freshness = {
            at     = "$${{ headers[\"sentry-hook-timestamp\"] }}"
            within = "300s"
          }
        }
      }
      events = [
        {
          when  = "$${{ ${local.resource} == \"issue\" && body.action == \"created\" }}"
          raise = local.issue_created
        },
        {
          when  = "$${{ ${local.resource} == \"event_alert\" && body.action == \"triggered\" }}"
          raise = local.alert_triggered
        },
        {
          when = "$${{ ${local.resource} == \"issue\" && body.action == \"resolved\" }}"
          raise = {
            happening = "${var.integration}.issue.resolved"
            label     = "Issue resolved"
            summary   = "The Sentry issue was resolved."
            marks     = [{ kind = local.issue_mark, value = "$${{ body.data.issue.id }}" }]
          }
        },
        {
          when = "$${{ ${local.resource} == \"issue\" && body.action == \"unresolved\" }}"
          raise = {
            happening = "${var.integration}.issue.unresolved"
            label     = "Issue unresolved"
            summary   = "The Sentry issue was unresolved, or came back."
            marks     = [{ kind = local.issue_mark, value = "$${{ body.data.issue.id }}" }]
          }
        },
      ]
    }

    actions = merge({
      get-issue = {
        request = {
          method = "GET"
          url    = "${local.issues_url}/${local.checked_issue}/"
          auth   = local.auth
          expect = { success = "$${{ status >= 200 && status < 300 }}" }
        }
      }
      get-latest-event = {
        request = {
          method = "GET"
          url    = "${local.issues_url}/${local.checked_issue}/events/latest/"
          auth   = local.auth
          expect = { success = "$${{ status >= 200 && status < 300 }}" }
        }
      }
    }, local.resolve_actions)

    tools = {
      get-issue = {
        action      = "get-issue"
        description = "Read a Sentry issue: its title, status, level, culprit, counts and first and last seen times."
        inputs      = local.issue_input
        output      = "$${{ response }}"
      }
      get-latest-event = {
        action      = "get-latest-event"
        description = "Read the latest event of a Sentry issue, with its stack trace, breadcrumbs, tags and request. Use it to find where an error comes from."
        inputs      = local.issue_input
        output      = "$${{ response }}"
      }
    }

    on = local.resolve_on
  }
}
