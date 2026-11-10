provider "spotlight" {
  url = var.spotlight_url
}

module "sentry" {
  source = "../.."

  workspace     = "acme"
  team          = "core"
  organization  = "acme"
  spotlight_url = var.spotlight_url

  client_secret = var.sentry_client_secret
  auth_token    = var.sentry_auth_token

  line_role         = "delivery"
  station           = "triage"
  resolve_on_finish = "resolvedInNextRelease"
}

module "sentry_disabled" {
  source = "../.."

  create = false

  workspace    = "acme"
  team         = "core"
  organization = "acme"
}
