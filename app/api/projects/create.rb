require 'json'
require 'aws-sdk'
require 'securerandom'

def handler(event:, context:)
  user_id = event.dig("requestContext", "authorizer", "claims", "sub")
  database = Aws::DynamoDB::Client.new(region: ENV["AWS_REGION"])

  request_body = event["body"] ? JSON.parse(event["body"]) : nil
  new_project_id = SecureRandom.uuid

  project = {
    item: {
      "hk" => new_project_id,
      "rk" => "PROJECT",
      "project_name" => request_body["name"]
    }
  }

  user_project = {
    item: {
      "hk" => "user##{user_id}",
      "rk" => "project##{new_project_id}"
    }
  }

  project_name_constraint = {
    item: {
      "hk" => "project_name##{project[:item]["project_name"]}",
      "rk" => "PROJECT"
    },
    condition_expression: "attribute_not_exists(hk)"
  }

  # Build a transaction for records needed
  transact_items = [
    project,
    user_project,
    project_name_constraint
  ].map do |record|
    {
      put: {
        table_name: ENV["PROJECTS_TABLE"],
        item: record[:item],
        condition_expression: record[:condition_expression]
      }
    }
  end

  begin
    database.transact_write_items({transact_items: transact_items})

    {
      statusCode: 200,
      body: JSON.generate({
        project: {
          id: project[:item]["hk"],
          name: project[:item]["project_name"]
        }
      })
    }
  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to create project:"
    puts error.inspect
    { statusCode: 400, body: JSON.generate(error.message) }
  end
end
