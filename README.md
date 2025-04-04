# Datastore V2
This repo is the second iteration of creating an IaC driven AWS infrastructure for a very simple backend server I want to handle a test website built from https://github.com/zacsketches/form_v2.

terraform/
├── bootstrap/          # This is its own terraform project OUT of the main module.
│   ├── main.tf         # Defines backend resources like S3 bucket, DynamoDB table, etc.
│   ├── variables.tf    # Variables specific to backend configuration.
│   ├── outputs.tf      # Outputs (if needed) for other components to reference.
│   └── terraform.tfvars # Backend-specific variable values.
├── compute/
│   ├── main.tf         # Compute-related resources (e.g., VMs, containers, etc.).
│   ├── variables.tf    # Variables for compute resources.
│   ├── outputs.tf      # Outputs for compute module.
│   └── terraform.tfvars # Compute-specific variable values.
├── persistent/
│   ├── main.tf         # Persistent storage resources (e.g., databases, storage accounts).
│   ├── variables.tf    # Variables for persistent infrastructure.
│   ├── outputs.tf      # Outputs for persistent module.
│   └── terraform.tfvars # Persistent-specific variable values.
└── main.tf             # Root configuration that ties modules together (optional).


## main.tf
This terraform stands up a free tier EC2 instance using the credentials loaded into the AWS CLI on the developer's laptop. This EC2 instance provides the VM for the backend compute.

## setup.sh
This bash script is run as the EC2 `user_data` when the new VM is created. The primary purpose of this script is to install Go and then build the microservice that serves as the webhook backend. The backend is cloned from https://github.com/zacsketches/webhook-handler. After `go build -o webhook-service` the new service is run under `systemd` control with restart enabled.

## Helpful Command Line Foo
#### Edit AWC CLI credentials
Using `terraform plan|apply|destroy` rely on the login credentials stored in the AWS CLI. When you rotate access keys the following tools help.
```
vim ~/.aws/credentials
```
Then delete the lines with the expired/deprecated access key and secret access key.  After that configure AWS and put in your new credentials. 
```
aws configure
```

#### Put the elastic IP into the environment
Most of the command line foo below is dependent on the presence of an environment variable called `EIP`.
```
export EIP=$(terraform output -raw webhook_ip)
```

#### Clear the EC2 fingerprint hash
When the background EC2 changes, but the Elastic IP stays the same, the SSH client thinks that there is a man in the middle attack. Get rid of the old fingerprint before attempting to log in.
```
ssh-keygen -R $EIP
```

#### Log into the backend via ssh
This usually requires removing the old fingerprint if the backend infra has been upgraded since the last login
```
ssh -i my-key-pair.pem ec2-user@$EIP
```

#### Follow the journald log of the web service
This command implements the traditional `tail -f <log>` functioality for `journald`
```
sudo journalctl -u webhook.service -f
```

#### Inspect the system log when the EC2 was built
I'm building the Go backend service on the EC2 box when it is stood up by terraform. So, this sometimes fails to build if the program has an error in it. To see the log I need to look at the system log on the EC2 box that is generate when AWS stands it up. 
```
sudo cat /var/log/cloud-init-output.log
```
Alternatively, follow the initialization as it is happening.
```
sudo tail -f /var/log/cloud-init-output.log
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
curl -i -X OPTIONS http://$EIP:8080/webhook
```
Commit [27a18da](https://github.com/zacsketches/webhook-handler/commit/27a18da1a8f1fec6e302adc4a4a9852344fbe0b1) on the webhook-handler limited `Content-Type` to `application/json`. This test sends the wrong `Content-Type` and should be rejected by the `/webhook`.
```
curl -i -X POST http://$EIP:8080/webhook \
-H "Content-Type: application/xml" \
-d '<user id="123" name="Alice" />'
```
