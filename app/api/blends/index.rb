require 'json'
require 'aws-sdk'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])

  begin
    projects = db.query(
      table_name: ENV['PROJECTS_TABLE'],
      key_condition_expression: "hk = :project and begins_with(rk, :blend)",
      expression_attribute_values: {
        ":project" => "project##{project_id}",
        ":blend" => 'blend'
      }
    ).items
    { statusCode: 200, body: JSON.generate(projects) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get blends:'
    puts error.message
    { statusCode: 400, body: "Failed to get blends" }
  end
end