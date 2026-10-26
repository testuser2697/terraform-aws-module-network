variable "prefix" {}
variable "base_tags" {}
variable "region" {}

variable "allow_groups" {
  type = map(list(string))

  validation {
    condition = alltrue(flatten([
      for group_name, cidrs in var.allow_groups : [
        for cidr in cidrs :
        trimspace(cidr) == "" || can(cidrhost(trimspace(cidr), 0))
      ]
    ]))
    error_message = "Every non-empty allow_groups CIDR must be a valid IPv4 CIDR value. Whitespace is tolerated, but malformed CIDRs are not."
  }
}

variable "security_group_rules" {
  type = map(object({
    type              = string
    protocol          = string
    destination_ports = list(string)
    source_cidrs      = optional(list(string), [])
    destination_cidrs = optional(list(string), [])
    allow_groups      = optional(list(string), [])
    description       = optional(string)
  }))

  validation {
    condition = alltrue([
      for rule_key, rule in var.security_group_rules :
      contains(["ingress", "egress"], lower(trimspace(rule.type)))
    ])
    error_message = "Each security group rule type must be either ingress or egress."
  }

  validation {
    condition = alltrue([
      for rule_key, rule in var.security_group_rules :
      contains(["tcp", "udp", "icmp", "1", "6", "17", "-1"], lower(trimspace(rule.protocol)))
    ])
    error_message = "Each security group rule protocol must be one of: tcp, udp, icmp, or -1."
  }

  validation {
    condition = alltrue([
      for rule_key, rule in var.security_group_rules :
      length([for p in rule.destination_ports : trimspace(p) if trimspace(p) != ""]) > 0
    ])
    error_message = "Each security group rule must include at least one non-empty destination port."
  }

  validation {
    condition = alltrue(flatten([
      for rule_key, rule in var.security_group_rules : [
        for p in rule.destination_ports :
        trimspace(p) != "" && can(tonumber(trimspace(p))) && tonumber(trimspace(p)) >= 0 && tonumber(trimspace(p)) <= 65535
      ]
    ]))
    error_message = "Each destination port must be a whole number between 0 and 65535."
  }

  validation {
    condition = alltrue(flatten([
      for rule_key, rule in var.security_group_rules : concat(
        [
          for cidr in try(rule.source_cidrs, []) :
          trimspace(cidr) == "" || can(cidrhost(trimspace(cidr), 0))
        ],
        [
          for cidr in try(rule.destination_cidrs, []) :
          trimspace(cidr) == "" || can(cidrhost(trimspace(cidr), 0))
        ]
      )
    ]))
    error_message = "Every non-empty source_cidrs and destination_cidrs value must be a valid IPv4 CIDR value. Whitespace is tolerated, but malformed CIDRs are not."
  }
}

variable "subnet_cidrs" {
  type        = map(string)
  description = "Map of subnet names to CIDR blocks."

  validation {
    condition = alltrue([
      for cidr in values(var.subnet_cidrs) :
      can(cidrhost(trimspace(cidr), 0))
    ])
    error_message = "Each subnet CIDR must be a valid CIDR block."
  }

  validation {
    condition     = contains(keys(var.subnet_cidrs), "app")
    error_message = "subnet_cidrs must include an 'app' subnet because EC2 instances are deployed into the app subnet."
  }

}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block used by the VPC. Must be a valid /16 CIDR block."
  validation {
    condition = (
      can(cidrhost(trimspace(var.vpc_cidr), 0)) &&
      tonumber(split("/", trimspace(var.vpc_cidr))[1]) == 16
    )
    error_message = "The VPC CIDR must be a valid /16 CIDR block, for example 10.50.0.0/16."
  }
}