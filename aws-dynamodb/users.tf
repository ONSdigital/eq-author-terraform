resource "aws_dynamodb_table" "author_users_table" {
  name           = "${var.env}-users"
  hash_key       = "id"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  tags {
    Name        = "${var.env}-users"
    Environment = "${var.env}"
  }
}

resource "aws_cloudwatch_metric_alarm" "author_users_table_read_throttled" {
  alarm_name          = "${var.env}-dynamodb-users-read-throttled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "EQ Author Users DynamoDB has had at least 1 read throttle error in the past 60 seconds"
  alarm_actions       = ["${var.slack_alert_sns_arn}"]

  dimensions {
    TableName = "${aws_dynamodb_table.author_users_table.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "author_users_table_write_throttled" {
  alarm_name          = "${var.env}-dynamodb-users-write-throttled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "EQ Author Users DynamoDB has had at least 1 write throttle error in the past 60 seconds"
  alarm_actions       = ["${var.slack_alert_sns_arn}"]

  dimensions {
    TableName = "${aws_dynamodb_table.author_users_table.name}"
  }
}

output "author_users_table_name" {
  value = "${aws_dynamodb_table.author_users_table.name}"
}

output "author_users_table_arn" {
  value = "${aws_dynamodb_table.author_users_table.arn}"
}
