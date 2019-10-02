# Lambda function, triggered every minute by a cloudwatch event.
# For each queue/asg combo, compute the BPI and send as cloudwatch metric
# An autoscaling policy on BPI allows quickly operating on a queue and spinning back down

require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
    cloudwatch_client = Aws::CloudWatch::Client.new()
    client = Aws::SQS::Client.new
    sqs = Aws::SQS::Resource.new(client: client)
    render_task_queues = sqs.queues(queue_name_prefix: "RenderTask")
    project_init_q = Aws::SQS::Queue.new(ENV["PROJECT_INIT_QUEUE"])
    asg_name = ENV["ASG_NAME"]

    combined_message_count = (render_task_queues.to_a + [project_init_q]).map{|q| queue.attributes["ApproximateNumberOfMessages"].to_f }.sum
    group_capacity = Aws::AutoScaling::AutoScalingGroup.new(asg_name).instances.select{|i| i.lifecycle_state == 'InService' }.count.to_f

    bpi = group_capacity > 0 ? combined_message_count/group_capacity : 1

    cloudwatch_client.put_metric_data(
      namespace: ENV["CLOUDWATCH_NAMESPACE"],
      metric_data: [
        {
          metric_name: 'BacklogPerInstance',
          value: bpi,
          unit: 'None',
          dimensions: [
            name: 'Queue',
            value: asg_name
          ]
        }
      ]
    ) 

    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
