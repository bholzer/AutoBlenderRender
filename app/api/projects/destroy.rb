require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  project = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}"
  }

  begin
    db.delete_item(table: ENV["PROJECTS_TABLE"], item: project)
    { statusCode: 200, body: project_id }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error
    { statusCode: 400, body: "Failed to destroy object" }
  end
end
