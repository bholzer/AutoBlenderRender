require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    sqs = Aws::SQS::Client.new(region: ENV["REGION"])

    request_body = event["body"] ? JSON.parse(event["body"]) : nil

    puts event.inspect

    render_task_id = SecureRandom.uuid

    new_task = {
    	"StartedAt" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    	"StartFrame" => request_body["start_frame"],
    	"EndFrame" => request_body["end_frame"],
    	"RenderTaskId" => render_task_id,
      "QueueUrl" => sqs.create_queue("RenderTask#{render_task_id}").queue_url
    }

  begin
    res = db.update_item({
    	table_name: ENV['PROJECTS_TABLE'],
    	key: {
    		"ProjectId" => event["pathParameters"]["project_id"]
    	},
    	return_values: "ALL_NEW",
    	update_expression: "set #RenderTasks = list_append(if_not_exists(#RenderTasks, :EmptyList), :RenderTask)",
    	expression_attribute_names: {
    		"#RenderTasks" => "RenderTasks"
    	},
    	expression_attribute_values: {
    		":EmptyList" => [],
    		":RenderTask" => [new_task]
    	}
    })

    if new_task["StartFrame"] && new_task["EndFrame"]
      puts "Sending render messages..."
      (new_task["StartFrame"]..new_task["EndFrame"]).each do |frame|
        frame_q = Aws::SQS::Queue.new(new_task["QueueUrl"])
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
