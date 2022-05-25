require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  project_id = event["pathParameters"]["projectId"]
  db = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  project = {
    item: {
      "hk" => project_id,
      "rk" => "PROJECT",
      "project_name" => request_body["name"]
    }
  }

  user_project = {
    item: {
      "hk" => "user##{user_id}",
      "rk" => "project##{project_id}"
    }
  }

  project_name_constraint = {
    item: {
      "hk" => "project_name##{project[:item]["project_name"]}",
      "rk" => "PROJECT"
    }
  }

  # Build a transaction for records needed
  transact_items = [
    project,
    user_project,
    project_name_constraint
  ].map do |record|
    {
      delete: {
        table_name: ENV["PROJECTS_TABLE"],
        item: record[:item]
      }
    }
  end

  begin
    database.transact_write_items({transact_items: transact_items})
    { statusCode: 200, body: project_id }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to delete project:"
    puts error.message
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
