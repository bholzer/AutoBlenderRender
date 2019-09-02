require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
  event['Records'].each do |s3_event|
    uploaded_object = s3_event['s3']['object']
    object_key = uploaded_object['key']
    s3_client = Aws::S3::Client.new()
    bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
    metadata = bucket.object(object_key).metadata
    start_frame = metadata['start_frame']
    end_frame = metadata['end_frame']

    if start_frame && end_frame
      message_attributes = {
        "blendfile_key" => {
          string_value: object_key,
          data_type: "String"
        }
      }

      message_attributes["start_frame"] = {
        string_value: start_frame,
        data_type: "String"
      }

      message_attributes["end_frame"] = {
        string_value: end_frame,
        data_type: "String"
      }

      render_init_q = Aws::SQS::Queue.new(ENV["PROJECT_INIT_QUEUE"])
      render_init_q.send_message({
        message_body: "Blender Project Init",
        message_attributes: message_attributes
      })
    end
  end

  # TODO implement
  { statusCode: 200, body: event }
end
