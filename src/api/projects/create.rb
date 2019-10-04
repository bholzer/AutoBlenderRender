require 'json'
require 'aws-sdk'
require 'securerandom'
require 'shared'

include Shared

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    s3_client = Aws::S3::Client.new()
    bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
    request_body = event["body"] ? JSON.parse(event["body"]) : nil
    item = {
      "ProjectName" => request_body["name"],
      "ProjectId" => SecureRandom.uuid
    }
  begin
    db.put_item(table_name: ENV['PROJECTS_TABLE'], item: item)
    { statusCode: 200, body: JSON.generate(item) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
