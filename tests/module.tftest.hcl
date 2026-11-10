mock_provider "spotlight" {
  mock_data "spotlight_workspace" {
    defaults = {
      id = "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57"
    }
  }

  mock_data "spotlight_team" {
    defaults = {
      id = "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    }
  }
}

variables {
  workspace     = "acme"
  team          = "core"
  organization  = "acme"
  client_secret = "4f1c2d0e9b8a7c6d5e4f3a2b1c0d9e8f"
  auth_token    = "sntrys_test"
}

run "creates_the_secrets_and_the_integration" {
  assert {
    condition     = spotlight_secret.client[0].workspace_id == "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57" && spotlight_secret.client[0].name == "SENTRY_CLIENT_SECRET"
    error_message = "The client secret goes in the workspace, as SENTRY_CLIENT_SECRET."
  }

  assert {
    condition     = length(spotlight_secret.client[0].bindings) == 0
    error_message = "The client secret is never sent anywhere."
  }

  assert {
    condition     = [for each in spotlight_secret.auth_token[0].bindings : each.host] == ["sentry.io"] && spotlight_secret.auth_token[0].bindings[0].prefix == "Bearer "
    error_message = "The auth token goes only to sentry.io, as a bearer token."
  }

  assert {
    condition     = spotlight_integration.this[0].team_id == "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    error_message = "The integration belongs to the team."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.SENTRY_CLIENT_SECRET" && spotlight_integration.this[0].definition.webhook.verify.hmac.header == "sentry-hook-signature"
    error_message = "Deliveries are verified with the client secret."
  }

  assert {
    condition     = output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/sentry"
    error_message = "The webhook address is the team's address for the integration."
  }
}

run "opens_a_task_when_an_alert_fires" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[1].raise.opens.lineRole == "delivery" && !contains(keys(spotlight_integration.this[0].definition.webhook.events[0].raise), "opens")
    error_message = "By default an alert opens a task on the delivery lines, and a new issue opens none."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[1].raise.marks[0].kind == "sentry.issue" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[0].kind == "sentry.issue"
    error_message = "An alert and a new issue find the same task, by the issue."
  }

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.webhook.events[1].raise.opens), "station")
    error_message = "A task opens at the line's first work station by default."
  }
}

run "opens_a_task_for_each_new_issue" {
  command = plan

  variables {
    opens_on  = "issue"
    line_role = "bugs"
    station   = "triage"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.opens.lineRole == "bugs" && spotlight_integration.this[0].definition.webhook.events[0].raise.opens.station == "triage" && !contains(keys(spotlight_integration.this[0].definition.webhook.events[1].raise), "opens")
    error_message = "A new issue opens a task at the given line role and station, and an alert opens none."
  }
}

run "opens_no_task_without_a_line_role" {
  command = plan

  variables {
    line_role = null
  }

  assert {
    condition     = alltrue([for each in spotlight_integration.this[0].definition.webhook.events : !contains(keys(each.raise), "opens")])
    error_message = "No event opens a task."
  }
}

run "reads_issues_with_the_auth_token" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.actions["get-issue"].request.auth.secrets == ["secret.SENTRY_AUTH_TOKEN"] && startswith(spotlight_integration.this[0].definition.actions["get-latest-event"].request.url, "https://sentry.io/api/0/organizations/acme/issues/")
    error_message = "The tools read the organization's issues with the auth token."
  }

  assert {
    condition     = keys(spotlight_integration.this[0].definition.tools) == ["get-issue", "get-latest-event"]
    error_message = "Agents get the two read tools."
  }
}

run "leaves_the_issue_when_a_task_finishes_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.actions), "resolve") && !contains(keys(spotlight_integration.this[0].definition.on), "task.finished")
    error_message = "No issue is resolved by default."
  }
}

run "resolves_the_issue_when_its_task_finishes" {
  command = plan

  variables {
    resolve_on_finish = "resolvedInNextRelease"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.actions["resolve"].request.method == "PUT" && strcontains(spotlight_integration.this[0].definition.actions["resolve"].request.body, "\"status\": \"resolvedInNextRelease\"")
    error_message = "The issue gets the given status."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.finished"][0].to.thread, "\"sentry.issue\" in task.marks")
    error_message = "Only a task with an issue's mark resolves one, and no expression fails on another task."
  }
}

run "refuses_another_status" {
  command = plan

  variables {
    resolve_on_finish = "ignored"
  }

  expect_failures = [var.resolve_on_finish]
}

run "sends_the_token_to_the_given_sentry" {
  command = plan

  variables {
    sentry_url = "https://de.sentry.io/"
  }

  assert {
    condition     = spotlight_secret.auth_token[0].bindings[0].host == "de.sentry.io" && startswith(spotlight_integration.this[0].definition.actions["get-issue"].request.url, "https://de.sentry.io/api/0/")
    error_message = "The token and the requests go to the given Sentry."
  }
}

run "refuses_a_sentry_url_with_a_path" {
  command = plan

  variables {
    sentry_url = "https://sentry.io/api/0"
  }

  expect_failures = [var.sentry_url]
}

run "names_everything_after_the_integration" {
  command = plan

  variables {
    integration = "errors"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[1].raise.happening == "errors.alert.triggered" && spotlight_integration.this[0].definition.webhook.events[1].raise.marks[0].kind == "errors.issue"
    error_message = "Happenings and mark kinds start with the integration's name."
  }

  assert {
    condition     = output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/errors"
    error_message = "The webhook address ends with the integration's name."
  }
}

run "uses_existing_secrets" {
  command = plan

  variables {
    create_secrets     = false
    client_secret      = null
    auth_token         = null
    client_secret_name = "ACME_SENTRY_CLIENT"
    auth_token_name    = "ACME_SENTRY_TOKEN"
  }

  assert {
    condition     = length(spotlight_secret.client) == 0 && length(spotlight_secret.auth_token) == 0
    error_message = "No secrets are created."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.ACME_SENTRY_CLIENT" && spotlight_integration.this[0].definition.actions["get-issue"].request.auth.secrets == ["secret.ACME_SENTRY_TOKEN"]
    error_message = "The integration names the existing secrets."
  }
}

run "creates_nothing_when_disabled" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = length(spotlight_integration.this) == 0 && length(spotlight_secret.client) == 0 && length(spotlight_secret.auth_token) == 0
    error_message = "A disabled module creates no resources."
  }

  assert {
    condition     = output.id == null && output.webhook_url == null && output.tools == {}
    error_message = "A disabled module's resource outputs are null."
  }
}

run "refuses_missing_secret_values" {
  command = plan

  variables {
    auth_token = null
  }

  expect_failures = [var.auth_token]
}

run "refuses_an_integration_name_with_a_dash" {
  command = plan

  variables {
    integration = "sentry-ops"
  }

  expect_failures = [var.integration]
}
