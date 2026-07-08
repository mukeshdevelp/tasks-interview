export TF_VAR_app_name="ecs-demo"
export TF_VAR_db_host="db.example.com"
export TF_VAR_api_key="replace-with-your-api-key"
export TF_VAR_db_password="replace-with-your-db-password"


# unsetting the variables
unset TF_VAR_db_host
unset TF_VAR_app_name
unset TF_VAR_api_key
unset TF_VAR_db_password


# what saved
aws ssm get-parameters \
  --names /ecs-task-app/APP_NAME /ecs-task-app/DB_HOST \
  --region eu-central-1


aws secretsmanager get-secret-value \
--secret-id ecs-task-app-api-key \
--region eu-central-1


aws secretsmanager get-secret-value \
--secret-id ecs-task-app-db-password \
--region eu-central-1