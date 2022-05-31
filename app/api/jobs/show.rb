require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  job_id = event["pathParameters"]["jobId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])
  s3_client = Aws::S3::Client.new()
  bucket = Aws::S3::Bucket.new(ENV["BUCKET_NAME"], client: s3_client)

  job = db.get_item(
    table_name: ENV["PROJECTS_TABLE"],
    key: {
      "hk" => "user##{user_id}",
      "rk" => "project##{project_id}#blend##{blend_id}#job##{job_id}"
    }
  ).item

  if job
    {
      statusCode: 200,
      body: JSON.generate({
        job: {
          id: job_id,
          project_id: project_id,
          blend_id: blend_id,
          type: job["type"]
          parameters: job["parameters"]
        }
      })
    }
  else
    { statusCode: 400, body: "" }
  end
end
