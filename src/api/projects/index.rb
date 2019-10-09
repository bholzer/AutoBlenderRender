require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    user_id = event.dig("requestContext", "authorizer", "claims", "sub")
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])

  begin
    projects = db.query(
      table_name: ENV['PROJECTS_TABLE'],
      key_condition_expression: "hk = :user and begins_with(rk, :project)",
      expression_attribute_values: {
        ":user" => "user##{user_id}",
        ":project" => 'project'
      }
    ).items
    { statusCode: 200, body: JSON.generate(projects) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate('Hello from Lambda!') }
  end

end
