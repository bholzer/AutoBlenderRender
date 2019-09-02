require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])

  begin
    resp = db.scan(table_name: ENV['PROJECTS_TABLE'])
    { statusCode: 200, body: JSON.generate(resp[:items]) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate('Hello from Lambda!') }
  end

end
