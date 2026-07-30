# Networking prerequisites for restoring the RDS instance into the DR
# region (eu-central-1). AWS Backup copies the recovery point across
# regions automatically, but restoring it still needs a DB subnet group
# and security group that exist in the target region/VPC.

data "aws_vpc" "dr_default" {
  provider = aws.dr
  default  = true
}

data "aws_subnets" "dr_default" {
  provider = aws.dr
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.dr_default.id]
  }
}

resource "aws_db_subnet_group" "dr" {
  provider   = aws.dr
  name       = "fincorp-dr-subnet-group"
  subnet_ids = data.aws_subnets.dr_default.ids

  tags = {
    Project = "fincorp"
  }
}

resource "aws_security_group" "dr_rds" {
  provider    = aws.dr
  name        = "fincorp-dr-rds-sg"
  description = "Allow Postgres access to the DR-restored fincorp DB from the operator IP only"
  vpc_id      = data.aws_vpc.dr_default.id

  ingress {
    description = "Postgres from operator IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "fincorp"
  }
}
