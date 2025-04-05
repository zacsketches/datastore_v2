# Datastore V2
This repo is the second iteration of creating an IaC driven AWS infrastructure for a very simple webhook backend server I want to handle the page built from https://github.com/zacsketches/form_v2. The infrastructure is in three projects.
1. Compute
2. Persistent
3. Bootstrap

-----
## Compute
  The main project launched from the root directory uses the `compute` module to `destroy|apply` a new EC2 instance whenever changes are made to the webhook handler.

### setup.sh
This bash script is run as the EC2 `user_data` when the new VM is created by the `compute` module. The primary purpose of this script is to install Go and then build the microservice that serves as the webhook backend. The backend is cloned from https://github.com/zacsketches/webhook-handler. After `go build -o webhook-service` the new service is run under `systemd` control with restart enabled. This script also puts a few convenient aliases into the `ec2-user .bashrc` file to `follow` the `journald` log for the `webhook.service` as well as `cloud-follow` and `cloud-cat` to respectively follow and list the instance initialization at `/var/log/cloud-init-output.log`.

-----
## Persistent
This module is its own terraform project which needs to be called from the root of the `/persistent` directory. This project sets up the infrastructure that should **NOT** be destroyed (i.e. elastic IPs, VPCs, etc).

-----
## Bootstrap
This module is also its own terraform project which needs to be run **BEFORE** anything else to create the remote state S3 and lock database. After running this plan the resources exist for the other modules to store their state and should be run in this order:
1. The `/persistent` module from its own folder
2. The main module from the project root which calls the `/compute` module

After running Bootstrap and then Persistent, you should not need to run them again.

-----
## Helpful command line foo
Here is some great stuff to cut and paste into the command line to drive testing of the infrastructure as it gets set up.

#### Swap out an old EC2 for a new one
The bash script `swap.sh` takes care of it all through terraform.
```
./swap.sh
```

#### Check to make sure the SQLite database has persisted
```
sqlite3 /mnt/readings/db/readings.db ".schema measurements_data"
```
We can also check the stats on the db
```
stat /mnt/readings/db/readings.db
```

#### Edit AWC CLI credentials
Using `terraform plan|apply|destroy` relies on the login credentials stored in the AWS CLI. When you rotate access keys the following tools help.
```
vim ~/.aws/credentials
```
Then delete the lines with the expired/deprecated access key and secret access key.  After that configure AWS and put in your new credentials. 
```
aws configure
```

#### See if the AWS client can log into ECR
With the EC2 associated to an IAM role the credentials should be in the instance's `aws` client.
```
aws ecr get-login-password --region us-east-1
```

#### Put the elastic IP into the environment
Most of the command line foo below is dependent on the presence of an environment variable called `EIP`.
```
export EIP=$(terraform output -raw webhook_ip)
```
Alternatively, use the utility program after adding `chmod +x` to it after cloning.
```
source ip.sh
```
#### Log into the backend via ssh
With the `-o StrictHostKeyChecking=no` this bypasses a little safety for the convenience of logging right into the newly created baceknd EC2's when the backend infra has been upgraded since the last login
```
ssh -i my-key-pair.pem -o StrictHostKeyChecking=no ec2-user@$EIP
```
Alternatively, use the utility program after exporting `EIP` into the shell environment.
```
./login.sh
```

#### Clear the EC2 fingerprint hash
When the background EC2 changes, but the Elastic IP stays the same, the SSH client thinks that there is a man in the middle attack. If you use `ssh` with the ill advised option `-o StrictHostKeyChecking=no` like it's shortcutted above this error will be ignored.  In production **DO NOT USE THIS OPTION** and tackle the real issue by getting rid of the old fingerprint before attempting to log in.
```
ssh-keygen -R $EIP
```

#### Follow the journald log of the web service
This command implements the traditional `tail -f <log>` functioality for `journald` and does not need `sudo` because the `webhook.service` belongs to `ec2-user`.
```
journalctl -u webhook.service -f
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
