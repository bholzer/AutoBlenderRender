require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  job_id = event["pathParameters"]["jobId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil

  job = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}#blend##{blend_id}#job##{job_id}",
  }

  begin
    db.delete_item(table_name: ENV["PROJECTS_TABLE"], item: job)
    { statusCode: 200, body: job_id }
  rescue Aws::DynamoDB::Errors::ServiceError => error
    { statusCode: 400, body: "Failed to destroy job" }
  end
end
