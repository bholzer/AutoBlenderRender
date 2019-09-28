require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    project_id = event["pathParameters"]["project_id"]
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  begin
    db.delete_item(table_name: ENV['PROJECTS_TABLE'], key: {"ProjectId" => project_id})
    { statusCode: 200, body: JSON.generate(item) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to delete project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
