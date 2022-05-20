require 'aws-sdk-sqs'
require 'worker/job'

module Worker
  class JobRunner
    def initialize
      @sqs_client = Aws::SQS::Client.new
      @job_queue = Aws::SQS::Queue.new(Worker.config[:job_queue], client: @sqs_client)
    end

    def self.start
      self.new.start
    end

    def get_message
      @job_queue.receive_messages(
        message_attribute_names: ["All"],
        max_number_of_messages: 1
      ).first
    end

    def message_attributes_to_hash(message)
      Hash[ message.message_attributes.map{|atr, val| [atr, val.string_value] } ]
    end

    def job_class_by_type(job_type)
      case job_type
      when "render"
        Worker::Job::Render
      # when :bake
      #   Worker::Job::Bake
      end
    end

    def execute_job(message)
      Worker.logger.info "Starting job"
      job_attributes = message_attributes_to_hash(message)
      job_class = job_class_by_type(job_attributes["type"])
      job = job_class.new(job_attributes)
      job.execute
      @job_queue.delete_messages({
        entries: [{id: message.message_id, receipt_handle: message.receipt_handle }]
      })
      Worker.logger.info "Job complete"
    end

    def start
      Worker.logger.info "Started the job runner"
      loop do
        job_message = get_message
        if job_message
          execute_job(job_message)
        end
        sleep 2
      end
    end
  end
end