terraform {
  required_version = ">= 1.5.0"

  # TODO: Migrate to GitLab SaaS backend (yourorg/production-homelab)
  # backend "http" {
  #   address        = "https://gitlab.com/api/v4/projects/yourorg%2Finfra/terraform/state/harvester"
  #   lock_address   = "https://gitlab.com/api/v4/projects/yourorg%2Finfra/terraform/state/harvester/lock"
  #   unlock_address = "https://gitlab.com/api/v4/projects/yourorg%2Finfra/terraform/state/harvester/lock"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  #   retry_wait_min = 5
  # }

  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = ">= 0.6.0"
    }
  }
}
