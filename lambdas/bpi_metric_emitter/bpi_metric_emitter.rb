# Lambda function, triggered every minute by a cloudwatch event.
# For each queue/asg combo, compute the BPI and send as cloudwatch metric
# An autoscaling policy on BPI allows quickly operating on a queue and spinning back down

require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    cloudwatch_client = Aws::CloudWatch::Client.new()
    queues_to_scale_by = [
        {
            url: ENV["FRAME_QUEUE"],
            asg: ENV["FRAME_QUEUE_ASG"],
            bpi: ENV["FRAME_QUEUE_BPI"]
        },
        {
            url: ENV["PROJECT_INIT_QUEUE"],
            asg: ENV["PROJECT_INIT_QUEUE_ASG"],
            bpi: ENV["PROJECT_INIT_QUEUE_BPI"]
        }
    ]
    
    queues_to_scale_by.each do |queue|
      q = Aws::SQS::Queue.new(queue[:url])
      queue_size = q.attributes["ApproximateNumberOfMessages"].to_f
      group_capacity = Aws::AutoScaling::AutoScalingGroup.new(queue[:asg]).instances.select{|i| i.lifecycle_state == 'InService' }.count.to_f
      backlog_per_instance = if queue_size == 0
        0
      else
        group_capacity > 0 ? queue_size/group_capacity : queue[:bpi].to_f+0.2 # Fake BPI threshold to kickoff task if capacity 0
      end

      cloudwatch_client.put_metric_data(
        namespace: ENV["CLOUDWATCH_NAMESPACE"],
        metric_data: [
          {
            metric_name: 'BacklogPerInstance',
            value: backlog_per_instance,
            unit: 'None',
            dimensions: [
              name: 'Queue',
              value: queue[:asg]
            ]
          }
        ]
      ) 
    end

    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
