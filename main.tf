data "archive_file" "my_lambda_function" {
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda.zip"
  type        = "zip"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-test-bucket-csv"
  acl    = "private"
  force_destroy = true
  tags = {
    Environment = "Dev"
  }
}

resource "aws_s3_account_public_access_block" "my_bucket" {
  block_public_acls   = true
  block_public_policy = true
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "s3_lambda_policy"
  description = "s3_lambda_policy_for_communication"

  policy = <<EOF
{
 "Version": "2020-11-08",
 "Statement": [
   {
     "Action": [
       "s3:ListBucket",
       "s3:GetObject",
       "s3:CopyObject",
       "s3:HeadObject"
     ],
     "Effect": "Allow",
     "Resource": [
       "arn:aws:s3:::my-test-bucket-csv",
       "arn:aws:s3:::my-test-bucket-csv/*"
     ]
   },
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Effect": "Allow",
     "Resource": "*"
   }
 ]
}
EOF
}

resource "aws_iam_role" "s3_copy_function" {
   name = "s3_lambda_copy_role"
   assume_role_policy = <<EOF
{
 "Version": "2020-11-08",
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

resource "aws_iam_role_policy_attachment" "terraform_lambda_iam_policy_basic_execution" {
 role = aws_iam_role.s3_copy_function.id
 policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "s3_copy_function" {
   filename = "lambda.zip"
   source_code_hash = data.archive_file.my_lambda_function.output_base64sha256
   function_name = "csv_s3_copy_lambda"
   role = aws_iam_role.s3_copy_function.arn
   handler = "index.handler"
   runtime = "python3.7"

   environment {
       variables = {
           DST_BUCKET = "my-test-bucket-csv",
           REGION = "ap-south-1"
       }
   }
}

resource "aws_lambda_permission" "allow_terraform_bucket" {
   statement_id = "AllowExecutionFromS3Bucket"
   action = "lambda:InvokeFunction"
   function_name = aws_lambda_function.s3_copy_function.arn
   principal = "s3.amazonaws.com"
   source_arn = aws_s3_bucket.my_bucket.arn
}

resource "aws_dynamodb_table" "example" {
  name           = "information"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "dynamodbHashKey"

  attribute {
    name = "dynamodbHashKey"
    type = "S"
  }
}