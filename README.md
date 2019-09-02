# AutoBlenderRender
Render farm for baking and rendering Blender creations.

I got tired of waiting forever for Blender animations to render, so I set out to create a render farm.
This project uses Terraform and AWS to build the infrastructure necessary to automate the rendering process.

Uses AWS and Terraform to build the infrastructure and kick off bake/render jobs.

To get started, you must have an AWS account with a payment method, and Terraform installed. https://www.terraform.io/

This configuration creates a few resources for automating the bake and render process:

S3
---

An S3 bucket is used to store blend files and rendered frames. Upload events are also used to trigger jobs.


VPC
---

Since EC2 instances are being created as job workers, they need a place to live. A VPC is created with a subnet, as well as some other resources to facilitate proper networking.

SQS
---

A few queues are created to store jobs. Workers poll these queues for something to do.

EFS
---

An EFS volume is created for sharing state between workers. Physics caches are baked to this location.

TODO: Develop mechanism for clearing this volume, as it could get expensive if allowed to grow.

EC2
---

Creates a launch template, autoscaling group and autoscaling policy. The launch template loads code onto the workers that pull jobs from the SQS queues. The autoscaling policy uses the queue sizes to determine scale.

TODO: fix the autoscale policy; it is too aggressive

Cloudwatch
---

Cloudwatch events are used to trigger scaling events per the autoscaling policy. A metric called "backlog per instance" (BPI) is created. BPI is simply queue size divided by the capacity of the autoscale group.

TODO: fix the autoscale policy; is BPI appropriate?

Lambda
---

Two functions are created:

bpi_emitter: calculates and emits the BPI metric every minute
bucket_upload_listener: listens for s3 upload events to then send jobs to the queue

Variables:

| Name  | Value |
|---|---|
| region | AWS region to place resources |
| availability_zone | availability zone in which to place workers |
| vpc_cidr | The CIDR of the VPC in which to place workers |
| render_bucket_name | Bucket to upload blend files and rendered frames |
| blender_node_image_id  |  AMI to use for worker nodes |
| instance_types  | List of instance types to use as workers  |
| worker_asg_name  | The name of the autoscaling group to put the workers into  |
| worker_node_max_count | Maximum number of workers to allow at once |
| node_key_name | Name of SSH key to add to worker nodes, for SSH access |
| cloudwatch_namespace | Name of Cloudwatch namespace used to trigger scaling events |