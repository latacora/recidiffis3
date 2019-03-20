resource "aws_s3_bucket" "lambda" {
  bucket = "recidiffist-s3-storage"
  acl    = "private"
}

resource "aws_s3_bucket_object" "jar" {
  bucket = "${aws_s3_bucket.lambda.id}"
  key    = "recidiffist.jar"
  source = "${var.jar_path}"
  etag   = "${md5(file(var.jar_path))}"
}

resource "aws_lambda_function" "recidiffist-s3" {
  function_name = "recidiffist-s3"
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "recidiffist_s3.core"
  runtime       = "java8"
  memory_size = 512
  timeout = 10
  environment = {
    variables = {
      SIEM_TYPE = "sns"
      LOG_NAME = "recidiffist-s3"
      SNS_TOPIC_ARN = "${var.sns_topic_arn}"
    }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.func.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${var.s3_bucket_arn}"
}


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.bucket.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.func.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log"
  }
}
