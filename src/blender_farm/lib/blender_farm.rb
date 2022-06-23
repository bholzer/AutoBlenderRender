require "blender_farm/version"
require "blender_farm/resources/user"
require "blender_farm/resources/project"
require "blender_farm/resources/blend"
require "blender_farm/resources/job"
require "logger"
require "aws-sdk-dynamodb"

module BlenderFarm
  class Error < StandardError; end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.dynamo_client
    @dynamo_client = Aws::DynamoDB::Client.new(region: BlenderFarm.config[:region])
  end

  def self.config
    @config ||= {
      region: ENV["AWS_REGION"],
      table: ENV["TABLE_NAME"]
    }
  end
end