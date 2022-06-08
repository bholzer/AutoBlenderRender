require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  file_name = request_body["file_name"]
  blend_id = SecureRandom.uuid
  signer = Aws::S3::Presigner.new

  blend = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}#blend##{blend_id}",
    "name" => file_name
  }

  blendfile_upload_url = signer.presigned_url(
    :put_object,
    bucket: ENV["BUCKET_NAME"],
    key: "#{user_id}/#{project_id}/#{blend_id}/#{file_name}"
  )

  begin
    db.put_item(table_name: ENV["PROJECTS_TABLE"], item: blend)

    {
      statusCode: 200,
      body: JSON.generate({
        blend: {
          id: blend_id,
          project_id: project_id,
          file_name: file_name,
          upload_url: blendfile_upload_url
        }
      })
    }

  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => error
    { statusCode: 400, body: "Blend already exists" }
  rescue Aws::DynamoDB::Errors::ServiceError => error
    { statusCode: 400, body: "Failed to create blend" }
  end
end
