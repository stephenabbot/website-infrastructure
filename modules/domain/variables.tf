variable "domain_name" {
  description = "Domain name for the static website"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "prod"
}

variable "coming_soon_content" {
  description = "Coming soon page HTML content"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "google_site_verification" {
  description = "Google Site Verification token for Search Console"
  type        = string
  default     = ""
}
