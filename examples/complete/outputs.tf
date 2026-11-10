output "webhook_url" {
  description = "The webhook URL to give in the Sentry internal integration."
  value       = module.sentry.webhook_url
}

output "tools" {
  description = "The integration's tools, by name."
  value       = module.sentry.tools
}

output "happenings" {
  description = "The happenings the integration raises."
  value       = module.sentry.happenings
}
