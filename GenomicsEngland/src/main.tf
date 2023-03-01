provider "aws" {
  region = "us-west-2"
}
#
resource "aws_iam_policy" "exif_s3_policy" {
  name = "exif_s3_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::genomcs/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "s3:PutObject",
        "Resource" : "arn:aws:s3:::englb/*"
      }
    ]
  })
}


resource "aws_iam_role" "exif-lambda_role" {
  name = "exif-lambda_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "exif_role_s3_policy_attachment" {
  name       = "exif_role_s3_policy_attachment"
  roles      = [aws_iam_role.exif-lambda_role.name]
  policy_arn = aws_iam_policy.exif_s3_policy.arn
}

resource "aws_iam_policy_attachment" "exif_role_lambda_policy_attachment" {
  name       = "exif_role_lambda_policy_attachment"
  roles      = [aws_iam_role.exif-lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "user_a_policy" {
  name = "user_a_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource" : [
          "arn:aws:s3:::bucket_a/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "user_a" {
  name = "user_a"
}

resource "aws_iam_user_policy_attachment" "user_a_policy_attachment" {
  user       = aws_iam_user.user_a.name
  policy_arn = aws_iam_policy.user_a_policy.arn
}

resource "aws_iam_policy" "user_b_policy" {
  name = "user_b_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject"
        ],
        "Resource" : [
          "arn:aws:s3:::bucket_b/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "user_b" {
  name = "user_b"
}

resource "aws_iam_user_policy_attachment" "user_b_policy_attachment" {
  user       = aws_iam_user.user_b.name
  policy_arn = aws_iam_policy.user_b_policy.arn
}

data "archive_file" "exif-lambda_source_archive" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/src/my-deployment.zip"
}

resource "aws_lambda_function" "exif-lambda" {
  depends_on       = [data.archive_file.exif-lambda_source_archive]
  function_name    = "exif_generation_lambda"
  filename         = "${path.module}/src/my-deployment.zip"
  runtime          = "python3.9"
  handler          = "app.lambda_handler"
  memory_size      = 256
  source_code_hash = data.archive_file.exif-lambda_source_archive.output_base64sha256
  role             = aws_iam_role.exif-lambda_role.arn
}

resource "aws_s3_bucket" "genomcs" {
  bucket = "genomcs"
}

resource "aws_s3_bucket" "englb" {
  bucket = "englb"
}

resource "aws_lambda_permission" "exif_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.exif-lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.genomcs.arn
}

resource "aws_s3_bucket_notification" "jpg_files" {
  bucket = aws_s3_bucket.genomcs.id
}

#