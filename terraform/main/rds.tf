data "aws_vpc" "default" {
  default = true
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_security_group" "rds" {
  name        = "fincorp-rds-sg"
  description = "Allow Postgres access to fincorp-primary-db from the operator IP only"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_db_instance" "primary" {
  identifier     = var.db_identifier
  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  skip_final_snapshot = true

  tags = {
    Project = "fincorp"
  }
}
