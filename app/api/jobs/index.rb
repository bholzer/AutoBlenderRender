require 'json'
require 'aws-sdk'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  begin
    jobs = db.query(
      table_name: ENV["PROJECTS_TABLE"],
      key_condition_expression: "hk = :user and begins_with(rk, :job)",
      expression_attribute_values: {
        ":user" => "user##{user_id}",
        ":job" => "project##{project_id}#blend##{blend_id}#job"
      }
    ).items

    {
      statusCode: 200,
      body: JSON.generate({
        jobs: jobs.map do |job|
          {
            id: job["rk"].split("#").last,
            project_id: project_id,
            blend_id: blend_id,
            type: job["type"],
            parameters: job["parameters"]
          }
        end
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to get jobs:"
    puts error.message
    { statusCode: 400, body: "Failed to get jobs" }
  end
end
