require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Job
      include DynamoResource
      attr_accessor :id, :blend
      db_attribute :type

      KEY_TEMPLATE = {
        hk: "user#%{user}",
        rk: "project#%{project}#blend#%{blend}#job#%{job}"
      }

      def initialize(id: SecureRandom.uuid, type: nil)
        @id = id
        @type = type
      end

      def key_params
        {
          project: blend.project.id,
          user: blend.project.user.id,
          blend: blend.id,
          job: id
        }
      end
    end
  end
end
