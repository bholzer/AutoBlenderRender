require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])

  blend = {
    "hk" => blend_id,
    "rk" => "BLEND"
  }

  project_blend = {
    "hk" => "project##{project_id}",
    "rk" => "blend##{blend_id}"
  }

  begin
    db.delete_item(table_name: ENV['PROJECTS_TABLE'], key: blend)
    db.delete_item(table_name: ENV['PROJECTS_TABLE'], key: project_blend)
    { statusCode: 200, body: project_id }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to delete blend:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
