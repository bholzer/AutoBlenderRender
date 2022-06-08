require 'aws-sdk-s3'
require 'fileutils'

module Worker
  class Cache
    attr_accessor :bucket

    def initialize(project_id)
      @project_id = project_id
      @bucket = Aws::S3::Bucket.new(Worker.config[:bucket], client: Aws::S3::Client.new())
    end

    def local_project_dir
      File.join(Worker.config[:efs_mount], @project_id)
    end

    def local_project_blendfile
      Dir[File.join(local_project_dir, '*.blend*')].first
    end

    def persist_project_from_s3
      local_dir = local_project_dir

      if !(File.directory?(local_dir) && local_project_blendfile)
        FileUtils.mkdir_p(local_dir)

        blendfile = @bucket.objects(prefix: "#{@project_id}/").find{|obj| obj.key.match(/\.blend\d*$/) }

        if blendfile
          blendfile.get(response_target: File.join(Worker.config[:efs_mount], blendfile.key))
        else
          puts "Could not find blendfile"
        end
      end
    end
  end
end
