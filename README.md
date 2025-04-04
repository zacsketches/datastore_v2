# Datastore V2
This repo is the second iteration of creating an IaC driven AWS infrastructure for a very simple backend server I want to handle a test website built from https://github.com/zacsketches/form_v2.

## main.tf
This terraform stands up a free tier EC2 instance using the credentials loaded into the AWS CLI on the developer's laptop. This EC2 instance provides the VM for the backend compute.

## setup.sh
This bash script is run as the EC2 `user_data` when the new VM is created. The primary purpose of this script is to install Go and then build the microservice that serves as the webhook backend. The backend is cloned from https://github.com/zacsketches/webhook-handler. After `go build -o myapp` the webhook microservice is run with

```
sudo -u ec2-user nohup ./myapp > /home/ec2-user/app.log 2>&1 &
```

## Helpful Command Line Foo
The following comands are helpful in interacting with the infrastructure during debug and testing.

#### Put the elastic IP into the environment
Most of the command line foo below is dependent on the presence of an environment variable called `EIP`.
```
export EIP=$(terraform output -raw webhook_ip)
```

#### EC2 fingerprint is changed
When the background EC2 changes, but the Elastic IP stays the same, the SSH client thinks that there is a man in the middle attack. Get rid of the old fingerprint before attempting to log in.
```
ssh-keygen -R $EIP
```

#### Test the webhook from the command line
This tests the default behavior, and includes the `-i` flag so we can see the CORS headers coming back from the server.
```
curl -i -X POST http://$EIP:8080/webhook \
-H "Content-Type: application/json" \
-d '{"value1": 42, "value2": 3.14}'
```
This tests to ensure that preflight CORS requests are functional.  The `/webhook` endpoint should log all responses, including CORS preflight.
```
curl -i -X OPTIONS http://<eip>:8080/webhook
```

