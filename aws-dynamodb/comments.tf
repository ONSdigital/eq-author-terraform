resource "aws_dynamodb_table" "author_comments_table" {
  name           = "${var.env}-comments"
  hash_key       = "questionnaireId"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "questionnaireId"
    type = "S"
  }

  tags {
    Name        = "${var.env}-comments"
    Environment = "${var.env}"
  }
}

resource "aws_cloudwatch_metric_alarm" "author_comments_table_read_throttled" {
  alarm_name          = "${var.env}-dynamodb-comments-read-throttled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "EQ Author Comments DynamoDB has had at least 1 read throttle error in the past 60 seconds"
  alarm_actions       = ["${var.slack_alert_sns_arn}"]

  dimensions {
    TableName = "${aws_dynamodb_table.author_comments_table.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "author_comments_table_write_throttled" {
  alarm_name          = "${var.env}-dynamodb-comments-write-throttled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "EQ Author Comments DynamoDB has had at least 1 write throttle error in the past 60 seconds"
  alarm_actions       = ["${var.slack_alert_sns_arn}"]

  dimensions {
    TableName = "${aws_dynamodb_table.author_comments_table.name}"
  }
}

output "author_comments_table_name" {
  value = "${aws_dynamodb_table.author_comments_table.name}"
}

output "author_comments_table_arn" {
  value = "${aws_dynamodb_table.author_comments_table.arn}"
}
