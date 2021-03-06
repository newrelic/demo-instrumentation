terraform {
    required_providers {
        newrelic = {
        source  = "newrelic/newrelic"
        version = "~> 2.9.0"
        }
    }
}

provider "newrelic" {
    api_key       = var.newrelic_api_key
    account_id    = var.newrelic_account_id
    region        = var.newrelic_region
}

{% if s3_bucketname_tfstate is defined %}
provider "aws" {
  access_key  = "{{ aws_access_key }}"
  secret_key  = "{{ aws_secret_key }}"
  region      = "{{ aws_region }}"
}
terraform {
  backend "s3" {
    bucket = "{{ s3_bucketname_tfstate }}"
    key    = "{{ deployment_name }}-{{ service_id }}-alerts.tfstate"
    access_key  = "{{ aws_access_key }}"
    secret_key  = "{{ aws_secret_key }}"
    region      = "{{ aws_region }}"
  }
}
{% endif %}

variable "service" {
    description = "The service to create alerts for"
    type = object({
        duration                   = number
        cpu_threshold              = number
        response_time_threshold    = number
        error_percentage_threshold = number
        throughput_threshold       = number
    })
}
variable "newrelic_api_key" {
    description = "The New Relic API key"
    type = string
}
variable "newrelic_account_id" {
    description = "The New Relic AccountId"
    type = string
}
variable "newrelic_region" {
    description = "The New Relic region for the account, typically US"
    type = string
}
variable "name" {
    description = "The application name to alert for"
    type = string
}

data "newrelic_entity" "application" {
    name = var.name
    domain = "APM"
    type = "APPLICATION"
}

resource "newrelic_alert_policy" "golden_signal_policy" {
    name = "Golden Signals - ${var.name}"
}

resource "newrelic_alert_condition" "response_time_web" {
    policy_id = newrelic_alert_policy.golden_signal_policy.id

    name            = "High Response Time (web)"
    type            = "apm_app_metric"
    entities        = [data.newrelic_entity.application.application_id]
    metric          = "response_time_web"
    condition_scope = "application"

    term {
        duration      = var.service.duration
        threshold     = var.service.response_time_threshold
        operator      = "above"
        priority      = "critical"
        time_function = "all"
    }
}

resource "newrelic_alert_condition" "throughput_web" {
    policy_id = newrelic_alert_policy.golden_signal_policy.id

    name            = "Low Throughput (web)"
    type            = "apm_app_metric"
    entities        = [data.newrelic_entity.application.application_id]
    metric          = "throughput_web"
    condition_scope = "application"

    term {
        duration      = var.service.duration
        threshold     = var.service.throughput_threshold
        operator      = "below"
        priority      = "critical"
        time_function = "all"
    }
}

resource "newrelic_alert_condition" "error_percentage" {
    policy_id = newrelic_alert_policy.golden_signal_policy.id

    name            = "High Error Percentage"
    type            = "apm_app_metric"
    entities        = [data.newrelic_entity.application.application_id]
    metric          = "error_percentage"
    condition_scope = "application"

    term {
        duration      = var.service.duration
        threshold     = var.service.error_percentage_threshold
        operator      = "above"
        priority      = "critical"
        time_function = "all"
    }
}

resource "newrelic_infra_alert_condition" "high_cpu" {
    policy_id = newrelic_alert_policy.golden_signal_policy.id

    name       = "High CPU usage"
    type       = "infra_metric"
    event      = "SystemSample"
    select     = "cpuPercent"
    comparison = "above"
    where      = "(`applicationId` = '${data.newrelic_entity.application.application_id}')"

    critical {
        duration      = var.service.duration
        value         = var.service.cpu_threshold
        time_function = "all"
    }
}
