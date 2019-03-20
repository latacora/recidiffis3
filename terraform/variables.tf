variable "s3_bucket_name" {
  description = "The name of the bucket to subscribe to"
}

variable "jar_path" {
  description = "The local filesystem path to the recidiffist-s3 standalone jar. This jar will be uploaded to S3."
}

variable "key_filter_prefix" {
  description = "The key filter prefix for events to subscribe to; see https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html#notification-how-to-filtering"
}

variable "key_filter_suffix" {
  description = "The key filter suffix for events to subscribe to; see https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html#notification-how-to-filtering"
}

variable "sns_topic_arn" {
  description = "The SNS topic ARN to subscribe to."
}
