require 'aws-sdk-sqs'
require 'farm_worker/job'

module FarmWorker
  class JobRunner
    def initialize
      @sqs_client = Aws::SQS::Client.new
      @mutex = Mutex.new
    end

    def self.start
      self.new.start
    end

    def queues_by_job_type
      {
        render: Aws::SQS::Resource.new(client: @sqs_client).queues(queue_name_prefix: "RenderTask"),
        bake: Aws::SQS::Queue.new(ENV["PROJECT_INIT_QUEUE"], client: @sqs_client)
      }
    end

    def get_message_from_queue(queue)
      queue.receive_messages(message_attribute_names: ["All"]).first
    end

    def message_attributes_to_hash(message)
      Hash.new[ message.message_attributes.map{|atr, val| [atr, val.string_value] } ]
    end

    def generate_job_thread_for_queue(queue)
      Thread.new do
        @mutex.synchronize do
          message = get_message_from_queue(queue)
          if message
            message_attributes = message_attributes_to_hash(message)
            @instance_protector.protect do
              job = FarmWorker::Job.create(type: job_type, **message_attributes)
              job.project_cache.persist_project_from_s3
              job.run
              queue.delete_messages({
                entries: [{id: message.message_id, receipt_handle: message.receipt_handle }]
              })
            end
          end
        end
      end
    end

    def start
      loop do
        queues_by_job_type.each do |job_type, queues|
          queues = [queues] unless queues.is_a?(Array) # wrap with array if necessary
          queues.map {|q| generate_job_thread_for_queue(q) }.each(&:join)
        end
      end
    end
  end
end