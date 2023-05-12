provider "aws" {
  region  = "us-east-1" # replace with your desired region
  profile = "dha"
}

variable "jar" {
  default = "demo-0.0.1-SNAPSHOT-aws.jar"
}

variable "handler" {
  default = "com.example.demo.RequestHandler"
}

data "aws_caller_identity" "current" {}

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

data "archive_file" "lambda" {
  type        = "zip"
  source_file = var.jar
  output_path = "lambda_function_payload.zip"
}

# Define the Lambda function
resource "aws_lambda_function" "function" {
  filename         = "lambda_function_payload.zip" # replace with the filename of your Lambda code
  function_name    = "lambda_madness"    # replace with your desired function name
  role             = aws_iam_role.lambda_role.arn # replace with the ARN of your IAM role for Lambda
  handler          = var.handler # replace with the name of your Lambda handler
  runtime          = "java17" # replace with your desired runtime
  source_code_hash = data.archive_file.lambda.output_base64sha256

  depends_on = [aws_iam_role.lambda_role, data.archive_file.lambda]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource
  .gateway_resource.path}"
}

# Define the IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  depends_on = [data.aws_iam_policy_document.assume_role]
}

# Define the API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "madness_api" # replace with your desired API name
}

# Define the API Gateway resource
resource "aws_api_gateway_resource" "gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "madness"

  depends_on = [aws_api_gateway_rest_api.api]
}

# Define the API Gateway method
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.gateway_resource.id
  http_method   = "GET" # replace with your desired HTTP method
  authorization = "NONE" # replace with your desired authorization type
  depends_on    = [aws_api_gateway_rest_api.api, aws_api_gateway_resource.gateway_resource]
}

# Define the API Gateway integration
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.gateway_resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST" # replace with your desired integration HTTP method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.function.invoke_arn # use the ARN of your Lambda function

  depends_on = [aws_api_gateway_rest_api.api, aws_api_gateway_resource.gateway_resource, aws_api_gateway_method.method, aws_lambda_function.function]
}
#
## Define the API Gateway method response
#resource "aws_api_gateway_method_response" "method_response" {
#  rest_api_id = aws_api_gateway_rest_api.api.id
#  resource_id = aws_api_gateway_resource.gateway_resource.id
#  http_method = aws_api_gateway_method.method.http_method
#  status_code = "200" # replace with your desired status code
#
#  depends_on = [aws_api_gateway_rest_api.api, aws_api_gateway_resource.gateway_resource, aws_api_gateway_method.method]
#}
#
## Define the API Gateway integration response
#resource "aws_api_gateway_integration_response" "integration_response" {
#  rest_api_id = aws_api_gateway_rest_api.api.id
#  resource_id = aws_api_gateway_resource.gateway_resource.id
#  http_method = aws_api_gateway_method.method.http_method
#  status_code = aws_api_gateway_method_response.method_response.status_code
#
#  depends_on = [aws_api_gateway_rest_api.api, aws_api_gateway_resource.gateway_resource, aws_api_gateway_method.method, aws_api_gateway_method_response.method_response]
#}