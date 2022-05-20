require 'worker/cache'

module Worker
  class Job
    def initialize(message_attributes)
      @message_attributes = message_attributes
    end

    def cache
      return nil if @message_attributes["project_id"].nil?
      @cache ||= Worker::Cache.new(@message_attributes["project_id"])
    end
  end
end

# require 'worker/job/bake'
require 'worker/job/render'