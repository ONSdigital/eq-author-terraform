resource "aws_wafregional_web_acl" "web_acl" {
  metric_name = "${var.metric_prefix}WebAcl"
  name = "${var.env}-web-acl"

  default_action {
    type = "BLOCK"
  }

  rule {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id = "${aws_wafregional_rule.allow_uk_traffic.id}"
    type = "REGULAR"

  }
}

resource "aws_wafregional_rule" "allow_uk_traffic" {

  metric_name = "${var.metric_prefix}AllowUkTraffic"
  name = "${var.env}-allow-uk-traffic"

  predicate {
    data_id = "${aws_wafregional_geo_match_set.uk_geo_match_set.id}"
    negated = false
    type = "GeoMatch"
  }

}

resource "aws_wafregional_geo_match_set" "uk_geo_match_set" {
  name = "${var.env}-uk-geo"

  geo_match_constraint {
    type = "Country"
    value = "GB"
  }

  geo_match_constraint {
    type = "Country"
    value = "IE"
  }
}

resource "aws_wafregional_web_acl_association" "web_acl_lb_association" {
  depends_on = ["aws_wafregional_web_acl.web_acl"]
  resource_arn = "${var.external_alb_arn}"
  web_acl_id   = "${aws_wafregional_web_acl.web_acl.id}"
}
