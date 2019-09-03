require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
	return { statusCode: 400, body: "No project ID provided" } unless event["pathParameters"]["project_id"]
    
    signer = Aws::S3::Presigner.new
    url = signer.presigned_url(:put_object, bucket: ENV["BUCKET"], key: "#{event["pathParameters"]["project_id"]}/main.blend")
    { statusCode: 200, body: url }
end
