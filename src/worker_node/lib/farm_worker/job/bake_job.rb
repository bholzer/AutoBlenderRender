require 'aws-sdk-sqs'

class FarmWorker::Job::Bake < Job
  BLENDER_SCRIPTS_LOCATION = "/blender_scripts"
  def run
    Dir.glob("#{BLENDER_SCRIPTS_LOCATION}/*.py").each do |blender_script_file|
      puts "Running blender..."
      blender_command = "/home/ec2-user/blender/blender -b #{project_cache.local_project_blendfile} -P #{blender_script_file}"
      system(blender_command)
      puts "Blender command complete"
    end
  end
end