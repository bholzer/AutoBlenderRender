require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  project_name = request_body["name"]
  project_id = SecureRandom.uuid

  project = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}",
    "name" => project_name
  }

  begin
    db.put_item(table_name: ENV["PROJECTS_TABLE"], item: project)

    {
      statusCode: 200,
      body: JSON.generate({
        project: {
          id: project_id,
          name: project_name
        }
      })
    }

  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => error
    { statusCode: 400, body: "Project already exists" }
  rescue Aws::DynamoDB::Errors::ServiceError => error
    { statusCode: 400, body: "Failed to create project" }
  end
end
