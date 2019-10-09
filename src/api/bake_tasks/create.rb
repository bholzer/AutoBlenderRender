require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    bake_q = Aws::SQS::Queue.new(ENV["PROJECT_INIT_QUEUE"])
    request_body = event["body"] ? JSON.parse(event["body"]) : nil
    user_id = event.dig("requestContext", "authorizer", "claims", "sub")
    project_id = event["pathParameters"]["project_id"]
    bake_task_id = SecureRandom.uuid

    puts event.inspect

    bake_task = {
      "hk" => bake_task_id,
      "rk" => "BAKE_TASK",
      "started_at" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    }

    project_bake_task = {
      "hk" => "project##{project_id}",
      "rk" => "bake_task##{render_task_id}",
    }

  begin
    task = db.put_item(table_name: ENV['PROJECTS_TABLE'], item: bake_task)
    project_task = db.put_item(table_name: ENV['PROJECTS_TABLE'], item: project_bake_task)

    bake_q.send_message(
      message_body: 'Body',
      message_attributes: {
        "project_id"=> {
          string_value: project_id,
          data_type: "String"
        },
        "bake_task_id"=>{
        	string_value: new_task["BakeTaskId"],
        	data_type: "String"
        }
      }
    )
  

    { statusCode: 200, body: JSON.generate("Message sent") }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
