variable "email_address" {
  description = "Email address for SNS subscription"
  type        = string
}

variable "phone_number" {
  description = "Phone number for SNS subscription"
  type        = string
}

variable "nba_api_key" {
  description = "The API key for the NBA data"
  type        = string
  sensitive   = true  # Mark as sensitive to prevent exposure in logs
}
