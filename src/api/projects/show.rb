require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    project_id = event["pathParameters"]["project_id"]
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    s3_client = Aws::S3::Client.new()
    bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)

    project = db.get_item(table_name: ENV['PROJECTS_TABLE'], key: {"ProjectId" => project_id}).item

    { statusCode: 200, body: JSON.generate(project) }
end
