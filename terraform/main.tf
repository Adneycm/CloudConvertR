provider "aws" {
  region="us-east-1"
}



# ----- S3 -----
resource "aws_s3_bucket" "input-bucket-cloud-project" {
  bucket = "input-bucket-cloud-project"
}

resource "aws_s3_bucket" "output-bucket-cloud-project" {
  bucket = "output-bucket-cloud-project"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input-bucket-cloud-project.id

  topic {
    topic_arn  = aws_sns_topic.uploaded-file-topic.arn
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
    resources = ["arn:aws:sns:*:*:uploaded-file-topic"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.input-bucket-cloud-project.arn]
    }
  }
}

resource "aws_sns_topic" "uploaded-file-topic" {
  name   = "uploaded-file-topic"
  policy = data.aws_iam_policy_document.topic.json
}


# ----- SQS -----
resource "aws_sqs_queue" "sqs-queue-files" {
  name = "sqs-queue-files"
}

resource "aws_sns_topic_subscription" "sqs_notification" {
  topic_arn = aws_sns_topic.uploaded-file-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs-queue-files.arn
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
    resources = [aws_sqs_queue.sqs-queue-files.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.uploaded-file-topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.sqs-queue-files.id
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
  output_path = "${path.module}/python/lambda-cloud-project.zip"
}

resource "aws_lambda_function" "lambda-test-cp" {
  filename      = "${path.module}/python/lambda-cloud-project.zip"
  function_name = "lambda-function-cp"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda-cloud-project.lambda_handler"   # <nome_do_arquivo.py>.<nome_da_função_dentro_do_arquivo>
  runtime       = "python3.8"
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.sqs-queue-files.arn
  function_name    = aws_lambda_function.lambda-test-cp.arn
}