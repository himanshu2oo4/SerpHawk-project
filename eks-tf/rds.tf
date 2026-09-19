resource "aws_db_subnet_group" "serphawk" {
  name = "serphawk-rds-subnet-group"

  subnet_ids = module.vpc.private_subnets

  tags = {
    Name        = "serphawk-rds-subnet-group"
    Project     = "SerpHawk"
    Environment = "dev"
  }
}

resource "aws_security_group" "rds" {
  name        = "serphawk-rds-sg"
  description = "Security group for SerpHawk PostgreSQL RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "serphawk-rds-sg"
    Project     = "SerpHawk"
    Environment = "dev"
  }
}

resource "aws_db_instance" "serphawk" {
  identifier = "serphawk-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "serphawk"
  username = "serphawk"

  manage_master_user_password = true

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.serphawk.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  multi_az = false

  backup_retention_period = 1

  skip_final_snapshot = true
  deletion_protection = false

  apply_immediately = true

  tags = {
    Name        = "serphawk-postgres"
    Project     = "SerpHawk"
    Environment = "dev"
  }
}