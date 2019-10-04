require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
  # Get all projects for this user from dynamo
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  sqs = Aws::SQS::Client.new(region: ENV["REGION"])
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")

  begin
    project = db.get_item(table_name: ENV['PROJECTS_TABLE'], key: {"ProjectId" => event["pathParameters"]["project_id"]}).item
    render_task = project["RenderTasks"].find{|rt| rt["RenderTaskId"] == event["pathParameters"]["render_task_id"]}

    { statusCode: 200, body: JSON.generate(render_task) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
