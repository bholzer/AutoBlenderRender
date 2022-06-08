require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  blend_id = event["pathParameters"]["blendId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])
  s3_client = Aws::S3::Client.new()
  bucket = Aws::S3::Bucket.new(ENV["BUCKET_NAME"], client: s3_client)

  blend = db.get_item(
    table_name: ENV["PROJECTS_TABLE"],
    key: {
      "hk" => "user##{user_id}",
      "rk" => "project##{project_id}#blend##{blend_id}"
    }
  ).item

  if blend
    {
      statusCode: 200,
      body: JSON.generate({
        blend: {
          id: blend_id,
          project_id: project_id,
          file_name: blend["name"]
        }
      })
    }
  else
    { statusCode: 400, body: "" }
  end
end
