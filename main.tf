resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.mod_tags, {
    Name = "${var.prefix}-vpc"
  })
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Demo security group"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    precondition {
      condition     = length(local.unknown_allow_groups) == 0
      error_message = "Unknown allow_groups were referenced. Every allow_group used by a rule must exist. Offending rules: ${jsonencode(local.unknown_allow_groups)}"
    }

    precondition {
      condition     = length(local.empty_ingress_rules) == 0
      error_message = "Every ingress rule must resolve to at least one effective CIDR. Empty ingress rules: ${jsonencode(keys(local.empty_ingress_rules))}"
    }

    precondition {
      condition     = length(local.empty_egress_rules) == 0
      error_message = "Every egress rule must resolve to at least one effective CIDR. Empty egress rules: ${jsonencode(keys(local.empty_egress_rules))}"
    }

    precondition {
      condition     = length(local.protocol_violations) == 0
      error_message = "Unsupported protocol values were found. Allowed protocols are tcp, udp, icmp, and -1. Offending rules: ${jsonencode(local.protocol_violations)}"
    }
  }

  tags = merge(local.mod_tags, {
    Name = "${var.prefix}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "rule" {
  for_each = local.effective_ingress_rules

  security_group_id = aws_security_group.main.id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr_ipv4
}

resource "aws_vpc_security_group_egress_rule" "rule" {
  for_each = local.effective_egress_rules

  security_group_id = aws_security_group.main.id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr_ipv4
}

resource "aws_subnet" "subnet" {
  for_each          = local.sanitized_subnet_cidrs
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.prefix}-subnet-${each.key}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.mod_tags, {
    Name = "${var.prefix}-rt"
  })
}

resource "aws_route_table_association" "subnet" {
  for_each = aws_subnet.subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.main.id
}
