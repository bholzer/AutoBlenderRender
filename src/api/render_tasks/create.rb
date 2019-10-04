require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
  # Get all projects for this user from dynamo
  db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
  sqs = Aws::SQS::Client.new(region: ENV["REGION"])
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")

  request_body = event["body"] ? JSON.parse(event["body"]) : nil

  puts event.inspect

  render_task_id = SecureRandom.uuid
  project_id = event["pathParameters"]["project_id"]
  status = 'started'

  render_task = {
    "hk" => render_task_id,
    "rk" => "RENDER_TASK",
    "data" => status,
    "started_at" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    "start_frame" => request_body["start_frame"],
    "end_frame" => request_body["end_frame"]
  }

  project_render_task = {
    "hk" => "project##{project_id}",
    "rk" => "render_task##{render_task_id}",
  }

  begin
    task = db.put_item(table_name: ENV['PROJECTS_TABLE'], item: render_task)
    project_task = db.put_item(table_name: ENV['PROJECTS_TABLE'], item: project_render_task)
    new_queue_url = sqs.create_queue(queue_name: "RenderTask#{render_task_id}").queue_url

    if render_task["start_frame"] && render_task["end_frame"]
      puts "Sending render messages..."
      (render_task["start_frame"]..render_task["end_frame"]).each do |frame|
        frame_q = Aws::SQS::Queue.new(new_queue_url)
        frame_q.send_message(
          message_body: 'Render Frame Triggered By Render Task',
          message_attributes: {
            "project_id"=> {
              string_value: event["pathParameters"]["project_id"],
              data_type: "String"
            },
            "frame"=>{
              string_value: frame.to_s,
              data_type: "String"
            },
            "render_task_id"=>{
              string_value: render_task_id,
              data_type: "String"
            }
          }
        )
      end
      puts "Render messages sent"
    end

    { statusCode: 200, body: JSON.generate(res.attributes) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
