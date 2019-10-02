require 'project_cache'
require 'job/bake_job'
require 'job/render_job'

class FarmWorker::Job
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