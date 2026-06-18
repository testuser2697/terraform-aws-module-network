locals {
  allow_groups_clean = {
    for group_name, cidrs in var.allow_groups :
    join("-", regexall("[a-z0-9]+", lower(trimspace(group_name)))) => distinct([
      for cidr in cidrs :
      trimspace(cidr)
      if trimspace(cidr) != ""
    ])
  }

  security_group_rules_clean = {
    for rule_key, rule in var.security_group_rules :
    join("-", regexall("[a-z0-9]+", lower(trimspace(rule_key)))) => {
      type     = lower(trimspace(rule.type))
      protocol = lower(trimspace(rule.protocol))
      destination_ports = distinct([
        for p in rule.destination_ports :
        trimspace(p)
        if trimspace(p) != ""
      ])
      source_cidrs = distinct([
        for cidr in try(rule.source_cidrs, []) :
        trimspace(cidr)
        if trimspace(cidr) != ""
      ])
      destination_cidrs = distinct([
        for cidr in try(rule.destination_cidrs, []) :
        trimspace(cidr)
        if trimspace(cidr) != ""
      ])
      allow_groups = distinct([
        for g in try(rule.allow_groups, []) :
        join("-", regexall("[a-z0-9]+", lower(trimspace(g))))
        if trimspace(g) != ""
      ])
      description = join(
        "-",
        regexall(
          "[a-z0-9]+",
          lower(trimspace(try(rule.description, rule_key)))
        )
      )
    }
  }

  ingress_rules_resolved = {
    for rule_key, rule in local.security_group_rules_clean :
    rule_key => merge(rule, {
      resolved_cidrs = distinct(concat(
        rule.source_cidrs,
        flatten([
          for g in rule.allow_groups :
          lookup(local.allow_groups_clean, g, [])
        ])
      ))
    })
    if rule.type == "ingress"
  }

  egress_rules_resolved = {
    for rule_key, rule in local.security_group_rules_clean :
    rule_key => merge(rule, {
      resolved_cidrs = distinct(concat(
        rule.destination_cidrs,
        flatten([
          for g in rule.allow_groups :
          lookup(local.allow_groups_clean, g, [])
        ])
      ))
    })
    if rule.type == "egress"
  }

  effective_ingress_rules = {
    for item in flatten([
      for rule_key, rule in local.ingress_rules_resolved : [
        for port in rule.destination_ports : [
          for cidr in rule.resolved_cidrs : {
            key         = "${rule_key}|${rule.protocol}|${port}|${cidr}"
            rule_key    = rule_key
            protocol    = rule.protocol
            port        = tonumber(port)
            cidr_ipv4   = cidr
            description = rule.description
          }
        ]
      ]
    ]) : item.key => item
  }

  effective_egress_rules = {
    for item in flatten([
      for rule_key, rule in local.egress_rules_resolved : [
        for port in rule.destination_ports : [
          for cidr in rule.resolved_cidrs : {
            key         = "${rule_key}|${rule.protocol}|${port}|${cidr}"
            rule_key    = rule_key
            protocol    = rule.protocol
            port        = tonumber(port)
            cidr_ipv4   = cidr
            description = rule.description
          }
        ]
      ]
    ]) : item.key => item
  }

  # ------------------------------
  # Checks/Guardrail helper locals
  # ------------------------------

  unknown_allow_groups = {
    for rule_key, rule in local.security_group_rules_clean :
    rule_key => [
      for g in rule.allow_groups : g
      if !contains(keys(local.allow_groups_clean), g)
    ]
    if length([
      for g in rule.allow_groups : g
      if !contains(keys(local.allow_groups_clean), g)
    ]) > 0
  }

  empty_ingress_rules = {
    for rule_key, rule in local.ingress_rules_resolved :
    rule_key => rule
    if length(rule.resolved_cidrs) == 0
  }

  empty_egress_rules = {
    for rule_key, rule in local.egress_rules_resolved :
    rule_key => rule
    if length(rule.resolved_cidrs) == 0
  }

  allowed_protocols = toset(["tcp", "udp", "icmp", "1", "6", "17", "-1"])

  protocol_violations = {
    for rule_key, rule in local.security_group_rules_clean :
    rule_key => rule.protocol
    if !contains(local.allowed_protocols, rule.protocol)
  }

  sanitized_subnet_cidrs = {
    for subnet_name, cidr in var.subnet_cidrs :
    trimspace(subnet_name) => trimspace(cidr)
  }

  mod_tags = merge(
    var.base_tags,
    { manager = "John Robinson (NetMod v1.0.1)"}
  )

}