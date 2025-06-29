terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }
}
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-vpc"
    }
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-igw"
    }
  )
}

resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-public-subnet-${local.az_names[count.index]}"
    }
  )
}



resource "aws_subnet" "private_subnet" {
  count             = length(var.private_subnet_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = local.az_names[count.index]
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-private-subnet-${local.az_names[count.index]}"
    }
  )
}


resource "aws_subnet" "db_subnet" {
  count             = length(var.db_subnet_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidr[count.index]
  availability_zone = local.az_names[count.index]
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-db-subnet-${local.az_names[count.index]}"
    }
  )
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  depends_on = [aws_eip.nat_eip]
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet[0].id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-public-route-table"
    }
  )
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-private-route-table"
    }
  )
}

resource "aws_route_table" "db_route_table" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags,
    {
      Name = "${var.project}-${var.env}-db-route-table"
    }
  )
}

resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igw.id
}

resource "aws_route" "private_route" {
  route_table_id            = aws_route_table.private_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.nat_gateway.id
}

resource "aws_route" "db_route" {
  route_table_id            = aws_route_table.db_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "private_association" {
  count          = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "db_association" {
  count          = length(var.db_subnet_cidr)
  subnet_id      = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_route_table.db_route_table.id
}