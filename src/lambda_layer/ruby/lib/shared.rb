require 'shared/model'
require 'shared/models/project'
require 'shared/authenticated_user'

module Shared
	def database
		@db ||= Aws::DynamoDB::Client.new(region: ENV['REGION'])
	end
end
