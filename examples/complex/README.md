# Complex Example
This complex example shows:
* how to use an existing ECS Cluster
* how to wire up fargate with DynamoDb
* how to mount an EFS mount

To use this example:
1. run `terraform init` 
2. run `terraform apply` (with a tag name)
3. copy the ecr repo URL from the outputs
4. run `cd src/`
5. run `npm install`
6. run `docker build -t <paste_ecr_repo_url>:<same_tage_name_from_step_2>`
7. [log into ecr](https://docs.aws.amazon.com/cli/latest/reference/ecr/get-login-password.html)
8. run `docker push <paste_ecr_repo_url>:<same_tage_name_from_step_2>`

Then you should be able to follow the logs in the AWS console to see if the task ran every 5 min.

The example docker image prints out the size of the dynamo table, and then it appends the timestamp to a file in the EFS and prints out the contents of the file.