#!/bin/ruby

require 'aws-sdk-s3'
require 'aws-sdk-autoscaling'
require 'aws-sdk-sqs'
require 'aws-sdk-ec2'
require 'fileutils'
require 'zlib'
require 'rubygems/package'

METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/'

class QueueRenderer
  def self.start_poll
    self.new.start_poll
  end

  def initialize
    @instance_id = Net::HTTP.get( URI.parse( METADATA_ENDPOINT + 'instance-id' ) )
    
    Aws.config.update(region: ENV["REGION"])
    s3_client = Aws::S3::Client.new()
    @bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
    @poller = Aws::SQS::QueuePoller.new(ENV["FRAME_QUEUE"])
  end

  def protect_from_scale_in(is_protected=true, current_retry: 0)
    as_client = Aws::AutoScaling::Client.new()
    begin
      as_client.set_instance_protection({
        auto_scaling_group_name: ENV["FRAME_QUEUE_ASG"],
        instance_ids: [@instance_id],
        protected_from_scale_in: is_protected
      })
    rescue Aws::AutoScaling::Errors::ValidationError => e
      # Instance isn't in a ready state and can't be protected.
      max_retries = 20
      if current_retry <= max_retries
        Thread.new do
          sleep 10
          protect_from_scale_in(true, current_retry: current_retry+1)
        end
      end
    end
  end

  def start_poll
    puts "Polling for frames to render."

    @poller.poll(skip_delete: true) do |msg|
      attrs = msg.message_attributes
      efs_mnt = "/mnt/efs"
      frame = attrs["frame"].string_value
      project_name = attrs["project"].string_value
      efs_project_dir = File.join(efs_mnt, project_name)
      blend_file_name = Dir[File.join(efs_project_dir, '*.blend*')].first

      puts "Got frame #{frame} for project #{project_name}"

      if File.directory?(efs_project_dir) && blend_file_name
        protect_from_scale_in
        output_file_name = "#{frame.rjust(4, "0")}.png"
        output_dir = '/tmp'

        blender_command = "/home/ec2-user/blender/blender --background #{blend_file_name} --use-extension 1 -noaudio -E CYCLES -t 0 -o #{output_dir}/ -F PNG -f #{frame}"
        system(blender_command)
        @bucket.object("#{project_name}/output/#{output_file_name}").upload_file(File.join(output_dir, output_file_name))
        @poller.delete_message(msg)
        protect_from_scale_in(false)
        puts "Frame finished rendering."
      else
        # Nothing to do for now
      end
    end
  end
end

puts "Starting queue renderer..."
QueueRenderer.start_poll
