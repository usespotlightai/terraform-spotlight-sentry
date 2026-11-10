variable "create" {
  description = "Whether to create the integration and its secrets. False creates nothing."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "The slug of the Spotlight workspace, as in `acme`."
  type        = string
}

variable "team" {
  description = "The key of the team the integration belongs to, as in `core`."
  type        = string
}

variable "organization" {
  description = "The slug of the Sentry organization, as in `acme`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.organization))
    error_message = "organization is a Sentry organization slug: lowercase letters, digits, dashes and underscores."
  }
}

variable "integration" {
  description = "The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `sentry.issue.created`. Fixed for the integration's life."
  type        = string
  default     = "sentry"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.integration)) && var.integration != "catalog"
    error_message = "integration is one word of lowercase letters and digits, and not catalog."
  }
}

variable "name" {
  description = "What the integration is called in the web app."
  type        = string
  default     = "Sentry"
}

variable "spotlight_url" {
  description = "The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "sentry_url" {
  description = "The address of the Sentry API, as in `https://de.sentry.io` for the EU region or the address of a self-hosted Sentry. The auth token is sent only to its host."
  type        = string
  default     = "https://sentry.io"

  validation {
    condition     = can(regex("^https://[^/:]+(:[0-9]+)?/?$", var.sentry_url))
    error_message = "sentry_url is an https address with no path, as in https://sentry.io."
  }
}

variable "line_role" {
  description = "The role of the lines that a Sentry issue opens a task on, as in `delivery`. Null opens no task: the happenings then only reach the tasks that already have the issue's mark."
  type        = string
  default     = "delivery"

  validation {
    condition     = var.line_role == null || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.line_role))
    error_message = "line_role is lowercase words joined by dashes, as in delivery."
  }
}

variable "station" {
  description = "The key of the station a task opens at, as in `triage`. Null opens it at the line's first work station."
  type        = string
  default     = null

  validation {
    condition     = var.station == null || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.station))
    error_message = "station is lowercase words joined by dashes, as in triage."
  }
}

variable "opens_on" {
  description = "What opens a task: `alert` when an issue alert rule that sends to the integration fires, or `issue` when Sentry creates an issue."
  type        = string
  default     = "alert"

  validation {
    condition     = contains(["alert", "issue"], var.opens_on)
    error_message = "opens_on is alert or issue."
  }
}

variable "resolve_on_finish" {
  description = "The status the Sentry issue gets when its task finishes: `resolved`, or `resolvedInNextRelease`. Null leaves the issue as it is."
  type        = string
  default     = null

  validation {
    condition     = var.resolve_on_finish == null || contains(["resolved", "resolvedInNextRelease"], coalesce(var.resolve_on_finish, "resolved"))
    error_message = "resolve_on_finish is resolved, resolvedInNextRelease or null."
  }
}

variable "create_secrets" {
  description = "Whether the module creates the two secrets from `client_secret` and `auth_token`. False uses the workspace secrets named `client_secret_name` and `auth_token_name`, which you keep yourself; the auth token's secret must then be bound to the host of `sentry_url` in the `authorization` header, with the prefix `Bearer `."
  type        = bool
  default     = true
}

variable "client_secret" {
  description = "The client secret of the Sentry internal integration, which signs its webhooks. Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "auth_token" {
  description = "An auth token of the Sentry internal integration. Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = !var.create_secrets || (var.client_secret != null && var.auth_token != null)
    error_message = "Give client_secret and auth_token, or set create_secrets to false."
  }
}

variable "secret_version" {
  description = "Change it when `client_secret` or `auth_token` changes, so Terraform sends the new values to Spotlight."
  type        = number
  default     = 1
}

variable "client_secret_name" {
  description = "The name of the workspace secret that holds the client secret."
  type        = string
  default     = "SENTRY_CLIENT_SECRET"
}

variable "auth_token_name" {
  description = "The name of the workspace secret that holds the auth token."
  type        = string
  default     = "SENTRY_AUTH_TOKEN"
}
