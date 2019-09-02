require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    # Get all projects for this user from dynamo

    puts event.inspect

    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
