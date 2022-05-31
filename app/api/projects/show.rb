require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])
  s3_client = Aws::S3::Client.new()
  bucket = Aws::S3::Bucket.new(ENV["BUCKET_NAME"], client: s3_client)

  project = {
    "hk" => "user##{user_id}",
    "rk" => "project##{project_id}"
  }

  begin
    project = db.get_item(table_name: ENV["PROJECTS_TABLE"], key: project).item
    {
      statusCode: 200,
      body: JSON.generate({
        project: {
          id: project["rk"].split("#").last,
          name: project["name"]
        }
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts error
    { statusCode: 400, body: "Failed to get project" }
  end
end
