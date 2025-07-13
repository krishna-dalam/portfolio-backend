variable "region" {
  default = "us-east-1"
}

variable "email_sender" {
  description = "Verified SES sender"
}

variable "email_recipient" {
  description = "Where form messages should be sent"
}
