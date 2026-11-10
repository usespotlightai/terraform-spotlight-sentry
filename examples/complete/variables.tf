variable "spotlight_url" {
  description = "The Spotlight the integration is created in."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "sentry_client_secret" {
  description = "The client secret of the Sentry internal integration."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "sentry_auth_token" {
  description = "An auth token of the Sentry internal integration."
  type        = string
  sensitive   = true
  ephemeral   = true
}
