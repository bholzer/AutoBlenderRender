#!/bin/ruby

require 'farm_worker/job_runner'
require 'farm_worker/instance_protector'
require 'farm_worker/project_cache'
require 'farm_worker/job'

module FarmWorker
  METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/'
  INSTANCE_ID = Net::HTTP.get( URI.parse( METADATA_ENDPOINT + 'instance-id' ) )
  EFS_MOUNT = "/mnt/efs"

  def self.instance_protector
    @instance_protector ||= FarmWorker::InstanceProtector.new
  end

  def self.instance_id
    @instance_id ||= Net::HTTP.get(URI.parse(METADATA_ENDPOINT + 'instance-id'))
  end

  def self.setup
    Aws.config.update(region: ENV["REGION"])
  end
end
