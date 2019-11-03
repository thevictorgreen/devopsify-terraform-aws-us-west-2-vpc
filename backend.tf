terraform {
  backend "s3" {
    bucket = "AAAAA"
    key    = "BBBBB"
    region = "us-west-2"
  }
}
