#!/bin/ruby

require 'aws-sdk-s3'
require 'aws-sdk-sqs'
require 'aws-sdk-ec2'
require 'fileutils'
require 'zlib'
require 'rubygems/package'

METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/'

BLENDER_SCRIPTS = {
  "bake_smoke.py" => %q(
import bpy

for scene in bpy.data.scenes:
    for object in scene.objects:
        for modifier in object.modifiers:
            if modifier.type == 'SMOKE':
                if modifier.smoke_type == 'DOMAIN':
                    override = {'scene': scene, 'active_object': object, 'point_cache': modifier.domain_settings.point_cache}
                    bpy.ops.ptcache.free_bake(override)
                    bpy.ops.ptcache.bake(override, bake=True)
                    break
)
}

class ProjectInit
  def self.start_poll
    self.new.start_poll
  end

  def initialize
    Aws.config.update(region: ENV["REGION"])

    s3_client = Aws::S3::Client.new()
    @bucket = Aws::S3::Bucket.new(ENV["BUCKET"], client: s3_client)
    @poller = Aws::SQS::QueuePoller.new(ENV["PROJECT_INIT_QUEUE"])
    @frame_q = Aws::SQS::Queue.new(ENV["FRAME_QUEUE"])
  end


  def start_poll
    @poller.poll(skip_delete: true) do |msg|
      attrs = msg.message_attributes
      efs_mnt = "/mnt/efs"
      blendfile_key = attrs["blendfile_key"].string_value
      start_frame = attrs["start_frame"] && attrs["start_frame"].string_value
      end_frame = attrs["end_frame"] && attrs["end_frame"].string_value
      blendfile = @bucket.object(blendfile_key)
      blendfile_path_segments = blendfile_key.split('/')
      project_name = blendfile_path_segments[0..-2]
      blendfile_filename = blendfile_path_segments.last 
      
      puts "Received Message: #{project_name} frames #{start_frame}-#{end_frame}"
      
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
        BLENDER_SCRIPTS.each do |filename, content|
          puts "Running blender..."
          blender_script_file = File.join('/home/ec2-user', filename)
          File.write(blender_script_file, content) # Persist the python script for passage to blender
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
          @frame_q.send_message(
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

      @poller.delete_message(msg)
    end
  end
end

ProjectInit.start_poll

