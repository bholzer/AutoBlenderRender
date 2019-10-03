require 'farm_worker/project_cache'
require 'farm_worker/job/bake'
require 'farm_worker/job/render'

module FarmWorker
  class Job
    JOB_TYPES = {
      render: FarmWorker::Job::Render,
      bake: FarmWorker::Job::Bake
    }

    def initialize(message_attributes)
      @message_attributes = message_attributes
    end

    def project_cache
      return nil if @message_attributes["project_id"].nil?
      @project_cache ||= FarmWorker::ProjectCache.new(@message_attributes["project_id"])
    end

    def self.create(type: , **message_attributes)
      JOB_TYPES[type].new(message_attributes)
    end
  end
end