provider "aws" {
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
      "execute-api:Invoke"
    ]
    resources = [
			"${aws_apigatewayv2_api.api.execution_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "AWS_IAM"
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync.arn
    field_log_level          = "ALL"
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

data "aws_arn" "apigw" {
  arn = aws_apigatewayv2_api.api.arn
}

resource "aws_appsync_datasource" "apigw" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "apigw"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "HTTP"
	http_config {
		endpoint = aws_apigatewayv2_api.api.api_endpoint
		authorization_config {
			authorization_type = "AWS_IAM"
			aws_iam_config {
				signing_region = data.aws_arn.apigw.region
				signing_service_name = "execute-api"
			}
		}
	}
}

# resolvers
resource "aws_appsync_resolver" "Query_call" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.apigw.name
  type        = "Query"
  field       = "call"
	request_template = <<EOF
{
	"version": "2018-05-29",
	"method": "GET",
	"params": {
		"headers": {
			"Content-Type" : "application/json"
		}
	},
	"resourcePath": $util.toJson($ctx.args.path)
}
EOF
	response_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#if ($ctx.result.statusCode < 200 || $ctx.result.statusCode >= 300)
	$util.error($ctx.result.body, "StatusCode$ctx.result.statusCode")
#end
$ctx.result.body
EOF
}

resource "aws_appsync_resolver" "Mutation_callPost" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.apigw.name
  type        = "Mutation"
  field       = "callPost"
	request_template = <<EOF
{
	"version": "2018-05-29",
	"method": "POST",
	"params": {
		"headers": {
			"Content-Type" : "application/json"
		},
		"body": $util.toJson($ctx.args.body)
	},
	"resourcePath": $util.toJson($ctx.args.path)
}
EOF
	response_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#if ($ctx.result.statusCode < 200 || $ctx.result.statusCode >= 300)
	$util.error($ctx.result.body, "StatusCode$ctx.result.statusCode")
#end
$ctx.result.body
EOF
}
