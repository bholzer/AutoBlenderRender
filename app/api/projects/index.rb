require 'json'
require 'aws-sdk'

def handler(event:, context:)
  # Get all projects for this user from dynamo
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  begin
    user_projects = db.query(
      table_name: ENV["PROJECTS_TABLE"],
      key_condition_expression: "hk = :user and begins_with(rk, :project)",
      expression_attribute_values: {
        ":user" => "user##{user_id}",
        ":project" => "project"
      }
    ).items

    project_ids = user_projects.map{|up| up["rk"].split("#").last }
    projects = db.batch_get_item({
      request_items: {
        ENV["PROJECTS_TABLE"] => {
          keys: project_ids.map do |pid|
            {"hk" => pid, "rk" => "PROJECT"}
          end
        }
      }
    }).responses[ENV["PROJECTS_TABLE"]]

    {
      statusCode: 200,
      body: JSON.generate({
        projects: projects.map do |project|
          {
            id: project["hk"],
            name: project["project_name"]
          }
        end
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to get projects:"
    puts error.message
    { statusCode: 400, body: "Failed to get projects" }
  end
end
