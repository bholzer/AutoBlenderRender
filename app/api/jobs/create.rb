require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  job_type = request_body["type"]
  job_params = request_body["parameters"]
  job_id = SecureRandom.uuid

  job = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}#blend##{blend_id}#job##{job_id}",
    "type" => job_type
    "parameters" => job_params
  }

  begin
    db.put_item(table_name: ENV["PROJECTS_TABLE"], item: job)

    {
      statusCode: 200,
      body: JSON.generate({
        job: {
          id: job_id,
          project_id: project_id,
          blend_id: blend_id,
          type: job_type
          parameters: job_params
        }
      })
    }

  rescue Aws::DynamoDB::Errors::ServiceError => error
    { statusCode: 400, body: "Failed to create job" }
  end
end
