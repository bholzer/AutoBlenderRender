require 'json'
require 'aws-sdk'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  begin
    blends = db.query(
      table_name: ENV["PROJECTS_TABLE"],
      key_condition_expression: "hk = :user and begins_with(rk, :blend)",
      expression_attribute_values: {
        ":user" => "user##{user_id}",
        ":blend" => "project##{project_id}#blend"
      }
    ).items

    {
      statusCode: 200,
      body: JSON.generate({
        blends: blends.map do |blend|
          {
            id: blend["rk"].split("#")[3],
            project_id: project_id,
            file_name: blend["name"]
          }
        end
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to get blends:"
    puts error.message
    { statusCode: 400, body: "Failed to get blends" }
  end
end
