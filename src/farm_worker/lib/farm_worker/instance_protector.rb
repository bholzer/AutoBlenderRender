require 'aws-sdk-autoscaling'

module FarmWorker
  class InstanceProtector
    def initialize
      @as_client = Aws::AutoScaling::Client.new()
    end

    def set_instance_protection(is_protected: , current_retry: 0)
      begin
        @as_client.set_instance_protection({
          auto_scaling_group_name: ENV["ASG_NAME"],
          instance_ids: [FarmWorker.instance_id],
          protected_from_scale_in: is_protected
        })
      rescue Aws::AutoScaling::Errors::ValidationError => e
        # Instance isn't in a ready state and can't be protected.
        max_retries = 20
        if current_retry <= max_retries
          Thread.new do
            sleep 10
            self.protect(is_protected, current_retry: current_retry+1)
          end
        end
      end
    end

    def protect
      self.set_instance_protection(is_protected: true)
      yield
      self.set_instance_protection(is_protected: false)
    end
  end
end