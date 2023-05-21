provider "aws" {
  region="us-east-1"
}

# ----- S3 -----
resource "aws_s3_bucket" "input-bucket-cloudconvertr" {
  bucket = "input-bucket-cloudconvertr"
}

resource "aws_s3_bucket" "output-bucket-cloudconvertr" {
  bucket = "output-bucket-cloudconvertr"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input-bucket-cloudconvertr.id

  topic {
    topic_arn  = aws_sns_topic.sns-CloudConvertR.arn
    events     = ["s3:ObjectCreated:Put", "s3:ObjectCreated:Post"]
  }
}

# ----- SNS -----
data "aws_iam_policy_document" "topic" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:sns-CloudConvertR"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.input-bucket-cloudconvertr.arn]
    }
  }
}

resource "aws_sns_topic" "sns-CloudConvertR" {
  name   = "sns-CloudConvertR"
  policy = data.aws_iam_policy_document.topic.json
}

# ----- SQS -----
resource "aws_sqs_queue" "sqs-CloudConvertR" {
  name = "sqs-CloudConvertR"
}

resource "aws_sns_topic_subscription" "sqs_notification" {
  topic_arn = aws_sns_topic.sns-CloudConvertR.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs-CloudConvertR.arn
}

data "aws_iam_policy_document" "sqs-policy" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.sqs-CloudConvertR.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.sns-CloudConvertR.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sqs-policy" {
  queue_url = aws_sqs_queue.sqs-CloudConvertR.id
  policy    = data.aws_iam_policy_document.sqs-policy.json
}


# ----- LAMBDA -----
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


data "archive_file" "zip_python_code" {
  type = "zip"
  source_dir  = "${path.module}/python/"
  output_path = "${path.module}/python/lambda-CloudConvertR.zip"
}

resource "aws_lambda_function" "lambda-CloudConvertR" {
  filename      = "${path.module}/python/lambda-CloudConvertR.zip"
  function_name = "lambda-CloudConvertR"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda-CloudConvertR.CloudConvertR"   # <nome_do_arquivo.py>.<nome_da_função_dentro_do_arquivo>
  runtime       = "python3.8"
  layers        = [aws_lambda_layer_version.lambda_layer_payload.arn]
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.sqs-CloudConvertR.arn
  function_name    = aws_lambda_function.lambda-CloudConvertR.arn
}

resource "aws_lambda_layer_version" "lambda_layer_payload" {
  filename   = "${path.module}/python/python.zip"
  layer_name = "markdown"
}

# ----- CLOUD WATCH -----
resource "aws_sns_topic" "sns-cloudwatch-CloudConvertR" {
  name   = "sns-cloudwatch-CloudConvertR"
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch-CloudConvertR" {
  alarm_name                = "cloudwatch-CloudConvertR"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 0
  alarm_description         = "This metric monitors Lambda function errors"
  alarm_actions             = [aws_sns_topic.sns-cloudwatch-CloudConvertR.arn]
  insufficient_data_actions = []
  dimensions = {
    FunctionName = aws_lambda_function.lambda-CloudConvertR.id
  }
}


data "aws_iam_policy_document" "sns-cloudwatch-policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:sns-cloudwatch-CloudConvertR"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_metric_alarm.cloudwatch-CloudConvertR.arn]
    }
  }
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.sns-cloudwatch-CloudConvertR.arn
  policy = data.aws_iam_policy_document.sns-cloudwatch-policy.json
}

variable "email" {
  type = string
}

resource "aws_sns_topic_subscription" "lambda_errors_email_notification" {
  topic_arn = aws_sns_topic.sns-cloudwatch-CloudConvertR.arn
  protocol  = "email"
  endpoint  = var.email
}
