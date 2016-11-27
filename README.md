# Docker Swarm and Spark example

You can see details in 

Running this will create some AWS instances so make sure you understand what the code is
doing and what costs will it incur. Run at your own risk.

To create the Swarm:
```
VPC_ID=<VPC_ID> ./provision
```

Destroy all instances.
```
./destroy
```
This will destroy EC2 instances but that does not necessary mean there won't be any
additional charges, like some persistent volumes if instances are created with such. So always
make sure in the AWS console that there are no services running that you will be charged for.
