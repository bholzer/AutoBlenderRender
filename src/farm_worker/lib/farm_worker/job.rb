require 'farm_worker/project_cache'

module FarmWorker
  class Job
    def initialize(message_attributes)
      @message_attributes = message_attributes
    end

    def project_cache
      return nil if @message_attributes["project_id"].nil?
      @project_cache ||= FarmWorker::ProjectCache.new(@message_attributes["project_id"])
    end
  end
end

require 'farm_worker/job/bake'
require 'farm_worker/job/render'
