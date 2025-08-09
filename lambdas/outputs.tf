output "rest_api_url" {
  value = aws_apigatewayv2_api.rest_api.api_endpoint
  description = "Invoke REST endpoint via POST /data"
}

output "websocket_api_url" {
  value = "${aws_apigatewayv2_api.ws_api.api_endpoint}/${aws_apigatewayv2_stage.ws_stage.name}"
  description = "WebSocket endpoint URL"
}