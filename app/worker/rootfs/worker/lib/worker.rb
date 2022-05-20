require "worker/version"
require 'worker/job_runner'
require 'logger'

module Worker
  class Error < StandardError; end

  EFS_MOUNT = "/mnt/efs"

  def self.start
    Aws.config.update(region: config[:region])
    job_runner.start
  end

  def self.job_runner
    @job_runner ||= Worker::JobRunner.new
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.config
    @config ||= {
      region: ENV["REGION"],
      efs_mount: "/mnt/efs",
      bucket: ENV["BUCKET"],
      job_queue: ENV["JOB_QUEUE"]
    }
  end
end