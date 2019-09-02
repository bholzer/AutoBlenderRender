require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    request_body = event["body"] ? JSON.parse(event["body"]) : nil
    item = {
      "ProjectName": request_body["name"]
    }
  begin
    db.put_item(table_name: ENV['PROJECTS_TABLE'], item: item)
    { statusCode: 200, body: JSON.generate(item) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
