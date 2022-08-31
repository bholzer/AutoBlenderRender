require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Blend
      include DynamoResource
      attr_accessor :id, :project, :jobs
      db_attribute :name

      KEY_TEMPLATE = {
        hk: "user#%{user}",
        rk: "project#%{project}#blend#%{blend}"
      }

      def initialize(id: SecureRandom.uuid, name: nil, jobs: [])
        @id = id
        @name = name
        @jobs = jobs
      end

      def key_params
        {
          project: project.id,
          user: project.user.id,
          blend: id
        }
      end

      def add_job(job)
        @jobs << job
        job.blend = self
      end
    end
  end
end
