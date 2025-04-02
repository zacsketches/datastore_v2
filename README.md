# Datastore V2
This repo is the second iteration of creating an IaC driven AWS infrastructure for a very simple backend server I want to handle a test website built from https://github.com/zacsketches/form_v2.

## main.tf
This terraform stands up a free tier EC2 instance using the credentials loaded into the AWS CLI on the developer's laptop. This EC2 instance provides the VM for the backend compute.

## setup.sh
This bash script is run as the EC2 `user_data` when the new VM is created. The primary purpose of this script is to install Go and then build the microservice that serves as the webhook backend. The backend is cloned from https://github.com/zacsketches/webhook-handler. After `go build -o myapp` the webhook microservice is run with

```
sudo -u ec2-user nohup ./myapp > /home/ec2-user/app.log 2>&1 &
```

