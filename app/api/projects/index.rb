require 'json'
require 'aws-sdk'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  begin
    projects = db.query(
      table_name: ENV["PROJECTS_TABLE"],
      key_condition_expression: "hk = :user_id",
      expression_attribute_values: {
        ":user_id" => "user##{user_id}"
      }
    ).items

    {
      statusCode: 200,
      body: JSON.generate({
        projects: projects.map do |project|
          {
            id: project["rk"].split("#").last,
            name: project["name"]
          }
        end
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error
    { statusCode: 400, body: "Failed to get projects" }
  end
end
