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

class ProjectPoller
  BLENDER_SCRIPTS_LOCATION = "/blender_scripts"

  def self.start
    puts "Started polling for new projects"
    Aws.config.update(region: ENV["REGION"])
    poller = Aws::SQS::QueuePoller.new(ENV["PROJECT_INIT_QUEUE"])
    frame_q = Aws::SQS::Queue.new(ENV["FRAME_QUEUE"])
    s3_client = Aws::S3::Client.new()
    bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)

    poller.poll(skip_delete: true) do |msg|
      attrs = msg.message_attributes
      efs_mnt = "/mnt/efs"
      blendfile_key = attrs["blendfile_key"].string_value
      start_frame = attrs["start_frame"] && attrs["start_frame"].string_value
      end_frame = attrs["end_frame"] && attrs["end_frame"].string_value
      blendfile = bucket.object(blendfile_key)
      blendfile_path_segments = blendfile_key.split('/')
      project_name = blendfile_path_segments[0..-2]
      blendfile_filename = blendfile_path_segments.last 
      
      puts "Received Message: #{project_name} frames #{start_frame}-#{end_frame}"
      InstanceProtector.protect
      
      efs_project_dir = File.join(efs_mnt, project_name)
      efs_blendfile_path = File.join(efs_project_dir, blendfile_filename)
      FileUtils.mkdir_p(efs_project_dir)
      blendfile.get(response_target: efs_blendfile_path) # Persist blendfile to EFS

      puts "Blendfile persisted to #{efs_blendfile_path}"

      # Two possible schemes for uploading jobs
      # 1. Regular .blend file. Will store and bake physics
      # 2. .tar.gz Assumed to budle .blend and already baked caches
      if blendfile_key.match(/\.blend\d*$/)      
        # Runs python scripts in different steps, so each step should be independent
        Dir.glob("#{BLENDER_SCRIPTS_LOCATION}/*.py").each do |blender_script_file|
          puts "Running blender..."
          blender_command = "/home/ec2-user/blender/blender -b #{efs_blendfile_path} -P #{blender_script_file}"
          system(blender_command)
          puts "Blender command complete"
        end
      elsif blendfile_key.match(/\.tar\.gz$/)
          system("tar -xzf #{efs_blendfile_path} -C #{efs_project_dir}")
      else
        # File type not recognized
      end

      # At this point, the project should be persisted to EFS and ready for rendering nodes to take over
      # If we have a frame range, it's time to queue them for rendering
      if start_frame && end_frame
        puts "Sending render messages..."
        (start_frame..end_frame).each do |frame|
          frame_q.send_message(
            message_body: 'Render Frame Triggered By Render Init',
            message_attributes: {
              "project"=> {
                string_value: project_name.join('/'),
                data_type: "String"
              },
              "frame"=>{
                string_value: frame.to_s,
                data_type: "String"
              }
            }
          )
        end
        puts "Render messages sent"
      end
      InstanceProtector.protect(false)

      poller.delete_message(msg)
    end
  end
end

class FramePoller
  def self.start
    puts "Started polling for new frames to render"
    Aws.config.update(region: ENV["REGION"])
    poller = Aws::SQS::QueuePoller.new(ENV["FRAME_QUEUE"])
    s3_client = Aws::S3::Client.new()
    bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
    poller.poll(skip_delete: true) do |msg|
      attrs = msg.message_attributes
      efs_mnt = "/mnt/efs"
      frame = attrs["frame"].string_value
      project_name = attrs["project"].string_value
      efs_project_dir = File.join(efs_mnt, project_name)
      blend_file_name = Dir[File.join(efs_project_dir, '*.blend*')].first

      puts "Got frame #{frame} for project #{project_name}"

      if File.directory?(efs_project_dir) && blend_file_name
        InstanceProtector.protect
        output_file_name = "#{frame.rjust(4, "0")}.png"
        output_dir = '/tmp'

        blender_command = "/home/ec2-user/blender/blender --background #{blend_file_name} --use-extension 1 -noaudio -E CYCLES -t 0 -o #{output_dir}/ -F PNG -f #{frame}"
        system(blender_command)
        bucket.object("#{project_name}/output/#{output_file_name}").upload_file(File.join(output_dir, output_file_name))
        poller.delete_message(msg)
        InstanceProtector.protect(false)
        puts "Frame finished rendering."
      else
        # Nothing to do for now
      end
    end
  end
end

class FarmWorker
  def self.start
    puts "Farm worker started"
    threads = []
    threads << Thread.new { ProjectPoller.start }
    threads << Thread.new { FramePoller.start }
    threads.each(&:join)
  end
end

FarmWorker.start
