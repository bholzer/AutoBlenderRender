module Shared
	class AuthenticatedUser
		attr_reader :pool_id, :id
		def initialize(lambda_event)
			authProvider = event.dig("requestContext", "identity", "cognitoAuthenticationProvider")
			@pool_id, @id = authProvider.split(":")
		end
	end
end