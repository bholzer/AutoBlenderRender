require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
  # Get all projects for this user from dynamo
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  sqs = Aws::SQS::Client.new(region: ENV["REGION"])
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["project_id"]
  render_task_id = event["pathParameters"]["render_task_id"]

  begin
    user_project = db.get_item(table_name: ENV['PROJECTS_TABLE'],key: {"hk" => "user##{user_id}", "rk" => "project##{project_id}"}).item
    render_task = db.get_item(table_name: ENV['PROJECTS_TABLE'], key: {"hk" => "project##{project_id}", "rk" => "render_task##{render_task_id}"}).item

    { statusCode: 200, body: JSON.generate(render_task) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
