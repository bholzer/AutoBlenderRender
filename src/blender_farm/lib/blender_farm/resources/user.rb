require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class User
      include DynamoResource
      attr_accessor :id, :projects

      KEY_TEMPLATE = {
        hk: "user#%{user}"
      }

      def initialize(id: SecureRandom.uuid, projects: [])
        @id = id
        @projects = projects
      end

      def key_params
        { user: id }
      end

      def add_project(project)
        @projects << project
        project.user = self
      end
    end
  end
end

