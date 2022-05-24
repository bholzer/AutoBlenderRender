require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  project_id = event["pathParameters"]["blendId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])
  s3_client = Aws::S3::Client.new()
  bucket = Aws::S3::Bucket.new(ENV["BUCKET_NAME"], client: s3_client)

  project_blend = db.get_item(
    table_name: ENV["PROJECTS_TABLE"],
    key: {
      "hk" => "project##{project_id}",
      "rk" => "blend##{blend_id}"
    }
  ).item

  if project_blend
    project = db.get_item(
      table_name: ENV["PROJECTS_TABLE"],
      key: {
        "hk" => blend_id,
        "rk" => "BLEND"
      }
    ).item
    { statusCode: 200, body: JSON.generate(project) }
  else
    { statusCode: 400, body: "" }
  end
end
