require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
  # Get all projects for this user from dynamo
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  sqs = Aws::SQS::Client.new(region: ENV["REGION"])
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["project_id"]

  begin
    render_tasks = db.query(
      table_name: ENV['PROJECTS_TABLE'],
      key_condition_expression: "hk = :project_id AND begins_with(rk, :render_task)",
      expression_attribute_values: {
        ":project_id" => "project##{project_id}",
        ":render_task" => 'render_task'
      }
    ).items
    { statusCode: 200, body: JSON.generate(render_tasks) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
