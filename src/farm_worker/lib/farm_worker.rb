require "farm_worker/version"
require 'farm_worker/job'
require 'farm_worker/job_runner'
require 'farm_worker/instance_protector'
require 'farm_worker/project_cache'
require 'logger'

module FarmWorker
  class Error < StandardError; end

  METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/'
  EFS_MOUNT = "/mnt/efs"

  def self.start
    setup
    job_runner.start
  end

  def self.instance_protector
    @instance_protector ||= FarmWorker::InstanceProtector.new
  end

  def self.job_runner
    @job_runner ||= FarmWorker::JobRunner.new
  end

  def self.instance_id
    @instance_id ||= Net::HTTP.get(URI.parse(METADATA_ENDPOINT + 'instance-id'))
  end

  def self.setup
    Aws.config.update(region: ENV["REGION"])
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end
