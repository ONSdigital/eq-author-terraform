resource "aws_elasticache_cluster" "author-redis" {
  cluster_id                   = "${var.env}-redis"
  engine                       = "redis"
  node_type                    = "cache.t2.micro"
  num_cache_nodes              = 1
  parameter_group_name         = "default.redis5.0"
  engine_version               = "5.0.4"
  subnet_group_name            = "${aws_elasticache_subnet_group.author-redis-subnet-group.name}"
  security_group_ids           = ["${aws_security_group.author-redis-access.id}"]
  availability_zone            = "eu-west-1a"
  port                         = 6379
}

resource "aws_elasticache_subnet_group" "author-redis-subnet-group" {
  name       = "${var.env}-redis-subnet-group"
  subnet_ids = ["${var.database_subnet_ids}"]
}

resource "aws_security_group" "author-redis-access" {
  name        = "${var.env}-redis-access"
  description = "Redis access from the application subnet"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = "${var.application_cidrs}"
  }

  tags {
    Name = "${var.env}-author-redis-security-group"
  }
}

output "author_redis_port" {
  value = "${aws_elasticache_cluster.author-redis.cache_nodes.0.port}"
}

output "author_redis_address" {
  value = "${aws_elasticache_cluster.author-redis.cache_nodes.0.address}"
}
