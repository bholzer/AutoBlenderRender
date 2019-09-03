require 'json'
require 'aws-sdk'
require 'securerandom'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo
    db = Aws::DynamoDB::Client.new(region: ENV['REGION'])
    request_body = event["body"] ? JSON.parse(event["body"]) : nil

    puts event.inspect

    new_task = {
    	"StartedAt" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
    	"StartFrame" => 1,
    	"EndFrame" => 50
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
    { statusCode: 200, body: JSON.generate(res.attributes) }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to create project:'
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
