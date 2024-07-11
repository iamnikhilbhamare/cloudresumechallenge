terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.47.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#create s3 bucket
resource "aws_s3_bucket" "bucketname" {
  bucket = var.bucketname
}

#object ownership

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucketname.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#Disable Block all public access option

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.bucketname.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#add files

resource "aws_s3_object" "index_file" {
  bucket = aws_s3_bucket.bucketname.id
  key    = "index.html"
  source = "index.html"
  acl    = "public-read"
  content_type = "text/html"
}

resource "aws_s3_object" "css_file" {
  bucket = aws_s3_bucket.bucketname.id
  key    = "styles.css"
  source = "styles.css"
  acl    = "public-read"
  content_type = "text/css"
}

resource "aws_s3_object" "js_file" {
  bucket = aws_s3_bucket.bucketname.id
  key    = "script.js"
  source = "script.js"
  acl    = "public-read"
  content_type = "text/javascript"
}


#Properties - Enable static website hosting

resource "aws_s3_bucket_website_configuration" "static_website_hosting" {
  bucket = aws_s3_bucket.bucketname.id

  index_document {
    suffix = "index.html"
  }
}

#bucket policy for OAC from cloudfront


resource "aws_s3_bucket_policy" "allow_access_from_another_service" {
  bucket = aws_s3_bucket.bucketname.id
  policy = jsonencode({
      "Version": "2008-10-17",
      "Id": "PolicyForCloudFrontPrivateContent",
      "Statement": [
          {                "Sid": "AllowCloudFrontServicePrincipal",
               "Effect": "Allow",
              "Principal": {
                  "Service": "cloudfront.amazonaws.com"
              },
              "Action": "s3:GetObject",
              "Action": "s3:PutObject"
              "Resource": "arn:aws:s3:::newcloudresume12341345256/*",                "Condition": {
                    "StringEquals": {
                      "AWS:SourceArn": "arn:aws:cloudfront::891377359650:distribution/E3J0FHW1NJABNG"
                    }
                }
            }
        ]
  })
}

# ACM Certificate Request

# resource "aws_acm_certificate" "ssl_certificate_request" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_acm_certificate_validation" "ssl_certificate_validation" {
#   certificate_arn = aws_acm_certificate.ssl_certificate_request.arn
# }

#----------------------------------------------------------------------------------
      #CLOUDFRONT CONFIGURATION:

locals {
  s3_origin_id = "${var.bucketname}-origin"
}

resource "aws_cloudfront_origin_access_identity" "aws_oai" {
  comment = "Some comment"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bucketname.bucket_domain_name
    origin_id                = local.s3_origin_id
        connection_attempts      = 3
    connection_timeout       = 10
    origin_path              = ""
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

#  aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 1
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# # Creating Route 53
# resource "aws_route53_zone" "hosted_zone" {
#   name = var.domain_name
# }

# resource "aws_route53_record" "record_name" {
#   zone_id = aws_route53_zone.hosted_zone.zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.s3_distribution.domain_name
#     zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
#     evaluate_target_health = true
#   }
# }

# CREATING DYNAMODB TABLE

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "v_counter"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "t_visitors"
  range_key      = "Count"

  attribute {
    name = "t_visitors"
    type = "S"
  }

  attribute {
    name = "Count"
    type = "N"
  }
}

resource "aws_dynamodb_table_item" "visitor_item" {
  table_name = aws_dynamodb_table.basic-dynamodb-table.name
  hash_key   = "t_visitors"
  range_key  = "Count"

  item = <<ITEM
{
  "t_visitors": {"S": "visitor"},
  "Count": {"N": "0"}
}
ITEM
}


#CREATING LAMBDA FUNCTION

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "VisitorCounter.py"
  output_path = "VisitorCounter.zip"
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "VisitorCounter.zip"
  function_name = "visitor_counter_function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "VisitorCounter.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.12"

}
