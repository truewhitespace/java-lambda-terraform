provider "aws" {
  region  = "us-east-1" # replace with your desired region
  profile = "dha"
}

variable "jar" {
  default = "demo-0.0.1-SNAPSHOT.jar"
}

variable "handler" {
  default = "com.example.demo.functions.RequestHandler::handleRequest"
}

data "aws_caller_identity" "current" {}

data "local_file" "lambda_jar" {
  filename = var.jar
}


module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "4.17.0"

  function_name = "lambda_madness"
  handler       = var.handler
  runtime       = "java17"

  local_existing_package = var.jar

  publish = true
  create_package = false
  allowed_triggers = {
    APIGatewayAny = {
      service = "apigateway"
      source_arn = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/${aws_api_gateway_stage.dev.stage_name}/*/*"
    }
  }
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
  http_method   = "ANY" # replace with your desired HTTP method
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
  uri                     = module.lambda_function.lambda_function_invoke_arn

  depends_on = [aws_api_gateway_rest_api.api, aws_api_gateway_resource.gateway_resource, aws_api_gateway_method.method, module.lambda_function]
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_rest_api.api]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"

  depends_on = [aws_api_gateway_deployment.deploy,aws_api_gateway_rest_api.api]
}

#resource "aws_api_gateway_method_settings" "example" {
#  rest_api_id = aws_api_gateway_rest_api.api.id
#  stage_name  = aws_api_gateway_stage.dev.stage_name
#  method_path = "*/*"
#
#  settings {
#    metrics_enabled = true
#    logging_level   = "INFO"
#  }
#
#  depends_on = [aws_api_gateway_rest_api.api, aws_api_gateway_stage.dev]
#}

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