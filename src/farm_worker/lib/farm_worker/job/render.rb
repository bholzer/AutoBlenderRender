module FarmWorker
  class Job::Render < Job
    def run
      frame = @message_attributes["frame"]
      project_id = @message_attributes["project_id"]
      render_task_id = @message_attributes["render_task_id"]

      puts "Got frame #{frame} for project #{project_id}"

      output_file_name = "#{frame.rjust(4, "0")}.png"
      output_dir = '/tmp'

      blender_command = "/usr/local/src/blender/2.80/blender --background #{project_cache.local_project_blendfile} --use-extension 1 -noaudio -E CYCLES -t 0 -o #{output_dir}/ -F PNG -f #{frame}"
      system(blender_command)
      project_cache.bucket.object("#{project_id}/#{render_task_id}/#{output_file_name}").upload_file(File.join(output_dir, output_file_name))
    end
  end
end