require "blender_farm/dynamo_resource"

module BlenderFarm
  module Resources
    class Job
      include DynamoResource

      attr_accessor :user_id, :project_id, :blend_id, :job_id, :type
      attr_writer :project, :blend

      def self.key_attributes
        {
          hk: [:user_id],
          rk: [:project_id, :blend_id, :job_id]
        }
      end

      def initialize(user_id:, project_id:, blend_id:, type:)
        @user_id = user_id
        @project_id = project_id
        @blend_id = blend_id
        @name = type
      end

      def project
        blend.project
      end

      def blend
        @blend ||= Blend.find(user_id: user_id, project_id: project_id, blend_id: blend_id)
      end
    end
  end
end
