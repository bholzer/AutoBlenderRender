module FarmWorker
	class Job::Bake < Job
	  BLENDER_SCRIPTS_LOCATION = "./blender_scripts"
	  def run
	    Dir.glob("#{BLENDER_SCRIPTS_LOCATION}/*.py").each do |blender_script_file|
	      puts "Running blender..."
	      blender_command = "/usr/local/src/blender/2.80/blender -b #{project_cache.local_project_blendfile} -P #{blender_script_file}"
	      system(blender_command)
	      puts "Blender command complete"
	    end
	  end
	end
end