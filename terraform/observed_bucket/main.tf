resource "aws_s3_bucket" "obs" {
  bucket = "recidiffis3-observed"
  acl    = "private"
}

resource "aws_s3_bucket_object" "obs" {
  bucket  = "${aws_s3_bucket.obs.id}"
  key     = "myfile.json"
  content = "${var.content}"
  etag    = "${md5(var.content)}"
}
