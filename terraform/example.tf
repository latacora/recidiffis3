resource "aws_s3_bucket" "lambda" {
  bucket = "recidiffis3-lambda-storage"
  acl    = "private"
}

resource "aws_s3_bucket_object" "jar" {
  bucket = "${aws_s3_bucket.lambda.id}"
  key    = "recidiffist.jar"
  source = "${var.jar_path}"
  etag   = "${md5(file(var.jar_path))}"
}

resource "aws_lambda_function" "recidiffis3" {
  function_name = "recidiffis3"
  s3_bucket     = "${aws_s3_bucket.lambda.id}"
  s3_key        = "${aws_s3_bucket_object.jar.id}"
  role          = "${aws_iam_role.lambda.arn}"
  handler       = "recidiffis3.core"
  runtime       = "java8"
  memory_size   = 512
  timeout       = 300

  environment = {
    variables = {
      SIEM_TYPE     = "sns"
      LOG_NAME      = "recidiffis3"
      SNS_TOPIC_ARN = "${var.sns_topic_arn}"
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

#
# Read from S3
#

# TODO: since we know the watched prefix and suffix, can we improve on the /*
# resource?

resource "aws_iam_policy" "s3_read" {
  name = "recidiffis3-read"
  path = "/"
  description = "IAM policy for allowing recidiffis3 to read from s3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:*"
      ],
      "Resource": "arn:aws:s3:::${var.s3_bucket_name}/*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "recidiffist_sns" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.s3_read.arn}"
}

#
# Publish to SNS
#

resource "aws_iam_policy" "sns_publish" {
  name = "recidiffis3-sns-publish"
  path = "/"
  description = "IAM policy for allowing recidiffis3 to read from s3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "sns:Publish"
      ],
      "Resource": "${var.sns_topic_arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sns_publish" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.sns_publish.arn}"
}

#
# Lambda logs
#

resource "aws_cloudwatch_log_group" "recidiffis3" {
  name              = "/aws/lambda/${aws_lambda_function.recidiffis3.function_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logs" {
  name = "recidiffis3-logs"
  path = "/"
  description = "IAM policy for logging from recidiffis3 lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.lambda_logs.arn}"
}

#
# S3 bucket writes -> lambda
#

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.recidiffis3.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${var.s3_bucket_name}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.recidiffis3.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "${var.key_filter_prefix}"
    filter_suffix       = "${var.key_filter_suffix}"
  }
}
