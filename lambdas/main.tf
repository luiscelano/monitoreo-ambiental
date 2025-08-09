# This Terraform config sets up:
# - A DynamoDB table with streams
# - A Lambda to handle HTTP POST (Arduino) and store data
# - A Lambda to read from DynamoDB stream and broadcast to WebSocket
# - REST API Gateway for Arduino
# - WebSocket API Gateway for real-time frontend updates

provider "aws" {
  region = "us-east-1"
}

###################################
# DynamoDB Table with Streams
###################################
resource "aws_dynamodb_table" "iot_data" {
  name           = "iot_data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "device_id"
  range_key      = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

###################################
# Lambda for POST (Arduino)
###################################
resource "aws_iam_role" "rest_lambda_role" {
  name = "rest_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rest_lambda_dynamodb" {
  role       = aws_iam_role.rest_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "rest_lambda_logging" {
  role       = aws_iam_role.rest_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "rest_lambda" {
  function_name = "rest_data_receiver"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.rest_lambda_role.arn
  filename      = "rest_lambda.zip"
  source_code_hash = filebase64sha256("rest_lambda.zip")
}

resource "aws_apigatewayv2_api" "rest_api" {
  name          = "iot_rest_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "rest_integration" {
  api_id             = aws_apigatewayv2_api.rest_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.rest_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "rest_route" {
  api_id    = aws_apigatewayv2_api.rest_api.id
  route_key = "POST /data"
  target    = "integrations/${aws_apigatewayv2_integration.rest_integration.id}"
}

resource "aws_apigatewayv2_stage" "rest_stage" {
  api_id      = aws_apigatewayv2_api.rest_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "rest_api_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rest_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rest_api.execution_arn}/*/*"
}

###################################
# WebSocket Lambda + API
###################################
resource "aws_iam_role" "ws_lambda_role" {
  name = "ws_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ws_policy_attach" {
  role       = aws_iam_role.ws_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}

resource "aws_lambda_function" "ws_lambda" {
  function_name = "dynamo_stream_to_ws"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.ws_lambda_role.arn
  filename      = "websocket_lambda.zip"
  source_code_hash = filebase64sha256("websocket_lambda.zip")
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn = aws_dynamodb_table.iot_data.stream_arn
  function_name    = aws_lambda_function.ws_lambda.arn
  starting_position = "LATEST"
}

resource "aws_apigatewayv2_api" "ws_api" {
  name          = "iot_ws_api"
  protocol_type = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "ws_integration" {
  api_id           = aws_apigatewayv2_api.ws_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ws_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "ws_route" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.ws_integration.id}"
}

resource "aws_apigatewayv2_stage" "ws_stage" {
  api_id      = aws_apigatewayv2_api.ws_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "ws_api_invoke" {
  statement_id  = "AllowWSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ws_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_api.execution_arn}/*/*"
}

resource "aws_iam_role_policy" "ws_lambda_dynamodb_stream" {
  name = "ws_lambda_dynamodb_stream_policy"
  role = aws_iam_role.ws_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.iot_data.stream_arn
      }
    ]
  })
}
