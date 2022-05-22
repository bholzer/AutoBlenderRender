require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  database = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  signer = Aws::S3::Presigner.new
  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  file_name = request_body["blend_file"]
  new_blend_id = SecureRandom.uuid
  
  blend_item = {
    "hk" => new_blend_id,
    "rk" => "BLEND",
    "FileName" => file_name
  }

  project_blend_item = {
    "hk" => "project##{project_id}",
    "rk" => "blend##{new_blend_id}"
  }

  blendfile_upload_url = signer.presigned_url(
    :put_object,
    bucket: ENV["BUCKET"],
    key: "#{project_id}/#{new_blend_id}/#{file_name}"
  )

  # Todo: check that project belongs to user
  begin
    database.put_item(table_name: ENV['PROJECTS_TABLE'], item: blend_item)
    database.put_item(table_name: ENV['PROJECTS_TABLE'], item: project_blend_item)
    { statusCode: 200, body: JSON.generate(blend_item.merge({upload_url: blendfile_upload_url})) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create blend:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end