require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  project = {
    "hk" => project_id,
    "rk" => "PROJECT"
  }

  user_project = {
    "hk" => "user##{project_id}",
    "rk" => "project##{project_id}"
  }
  begin
    db.delete_item(table_name: ENV["PROJECTS_TABLE"], key: project)
    db.delete_item(table_name: ENV["PROJECTS_TABLE"], key: user_project)
    { statusCode: 200, body: project_id }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to delete project:"
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
