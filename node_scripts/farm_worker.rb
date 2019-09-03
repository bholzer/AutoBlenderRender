#!/bin/ruby

require 'aws-sdk-s3'
require 'aws-sdk-autoscaling'
require 'aws-sdk-sqs'
require 'aws-sdk-ec2'
require 'fileutils'
require 'zlib'
require 'rubygems/package'

METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/'
INSTANCE_ID = Net::HTTP.get( URI.parse( METADATA_ENDPOINT + 'instance-id' ) )
EFS_MOUNT = "/mnt/efs"

class InstanceProtector
  def self.protect(is_protected=true, current_retry: 0)
    as_client = Aws::AutoScaling::Client.new()
    begin
      as_client.set_instance_protection({
        auto_scaling_group_name: ENV["ASG_NAME"],
        instance_ids: [INSTANCE_ID],
        protected_from_scale_in: is_protected
      })
    rescue Aws::AutoScaling::Errors::ValidationError => e
      # Instance isn't in a ready state and can't be protected.
      max_retries = 20
      if current_retry <= max_retries
        Thread.new do
          sleep 10
          self.protect(is_protected, current_retry: current_retry+1)
        end
      end
    end
  end
end

class JobPoller
  def initialize(queue)
    Aws.config.update(region: ENV["REGION"])
    @poller = Aws::SQS::QueuePoller.new(queue)
    s3_client = Aws::S3::Client.new()
    @bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
  end

  def local_project_dir(project_id)
    File.join(EFS_MOUNT, project_id)
  end

  def local_project_blendfile(project_id)
    Dir[File.join(local_project_dir(project_id), '*.blend*')].first
  end

  def persist_project_from_s3(project_id)
    local_dir = local_project_dir(project_id)

    if !(File.directory?(local_dir) && local_project_blendfile(project_id))
      FileUtils.mkdir_p(local_dir)

      blendfile = @bucket.objects(prefix: "#{project_id}/").find{|obj| obj.key.match(/[.]blend\d*$/) }
      blendfile.get(response_target: File.join(EFS_MOUNT, blendfile.key))
    end
  end

  def poll
    @poller.poll(skip_delete: true) do |msg|
      attrs = msg.message_attributes
      project_id = attrs["project_id"].string_value
      InstanceProtector.protect

      persist_project_from_s3(project_id) # Persisting locally to shared volume
      
      yield(msg)
      InstanceProtector.protect(false)
    end
  end
end

class BakePoller < JobPoller
  BLENDER_SCRIPTS_LOCATION = "/blender_scripts"
  def start
    self.poll do |msg|
      attrs = msg.message_attributes
      project_id = attrs["project_id"].string_value

      Dir.glob("#{BLENDER_SCRIPTS_LOCATION}/*.py").each do |blender_script_file|
        puts "Running blender..."
        blender_command = "/home/ec2-user/blender/blender -b #{local_project_blendfile(project_id)} -P #{blender_script_file}"
        system(blender_command)
        puts "Blender command complete"
      end

      @poller.delete_message(msg)
    end
  end
end

class FramePoller < JobPoller
  def start
    self.poll do |msg|
      attrs = msg.message_attributes
      frame = attrs["frame"].string_value
      project_id = attrs["project_id"].string_value
      render_task_id = attrs["render_task_id"].string_value

      puts "Got frame #{frame} for project #{project_id}"

      output_file_name = "#{frame.rjust(4, "0")}.png"
      output_dir = '/tmp'

      blender_command = "/home/ec2-user/blender/blender --background #{local_project_blendfile(project_id)} --use-extension 1 -noaudio -E CYCLES -t 0 -o #{output_dir}/ -F PNG -f #{frame}"
      system(blender_command)
      @bucket.object("#{project_id}/#{render_task_id}/#{output_file_name}").upload_file(File.join(output_dir, output_file_name))
      @poller.delete_message(msg)
    end
  end
end

class FarmWorker
  def self.start
    puts "Farm worker started"
    threads = []
    threads << Thread.new { BakePoller.new(ENV["PROJECT_INIT_QUEUE"]).start }
    threads << Thread.new { FramePoller.new(ENV["FRAME_QUEUE"]).start }
    threads.each(&:join)
  end
end

FarmWorker.start
