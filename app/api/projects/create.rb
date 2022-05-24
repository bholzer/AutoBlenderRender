require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  database = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  new_project_id = SecureRandom.uuid
  project_item = {
    "hk" => new_project_id,
    "rk" => "PROJECT",
    "data" => request_body["name"]
  }

  user_project_item = {
    "hk" => "user##{user_id}",
    "rk" => "project##{new_project_id}"
  }
  begin
    database.put_item(table_name: ENV["PROJECTS_TABLE"], item: project_item)
    database.put_item(table_name: ENV["PROJECTS_TABLE"], item: user_project_item)
    { statusCode: 200, body: JSON.generate(project_item) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to create project:"
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
