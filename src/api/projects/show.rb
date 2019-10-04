require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
  # Get all projects for this user from dynamo
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["project_id"]
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  s3_client = Aws::S3::Client.new()
  bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)

  user_project = db.get_item(table_name: ENV['PROJECTS_TABLE'], key: {"hk" => "user##{user_id}", "rk" => "project##{project_id}" }).item

  if user_project
    project = db.get_item(table_name: ENV['PROJECTS_TABLE'], key: {"hk" => project_id, "rk" => "PROJECT"}).item
    { statusCode: 200, body: JSON.generate(project) }
  else
    { statusCode: 400, body: "" }
  end
end
