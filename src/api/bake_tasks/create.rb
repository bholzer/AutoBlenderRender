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

    puts event.inspect

    new_task = {
    	"StartedAt" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    	"BakeTaskId" => SecureRandom.uuid
    }

  begin
    res = db.update_item({
    	table_name: ENV['PROJECTS_TABLE'],
    	key: {
    		"ProjectId" => project_id
    	},
    	return_values: "ALL_NEW",
    	update_expression: "set #BakeTasks = list_append(if_not_exists(#BakeTasks, :EmptyList), :BakeTask)",
    	expression_attribute_names: {
    		"#BakeTasks" => "BakeTasks"
    	},
    	expression_attribute_values: {
    		":EmptyList" => [],
    		":BakeTask" => [new_task]
    	}
    })

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
