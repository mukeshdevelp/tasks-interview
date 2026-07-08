pipeline {

    agent any

    environment {
        AWS_DEFAULT_REGION = "eu-central-1"

        TF_VAR_aws_region   = "eu-central-1"
        TF_VAR_project_name = "ecs-task-app"
        TF_VAR_owner        = "mukesh"
    }

    stages {

        stage('Checkout Source') {
            steps {
                git branch: 'master',
                    credentialsId: 'pat-token-github',
                    url: 'https://github.com/mukeshdevelp/tasks-interview.git'
            }
        }

        stage('Terraform Init - Task1') {
            steps {
                dir('task1-s3') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'p-17-tf-creds']
                    ]) {
                        sh '''
                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate - Task1') {
            steps {
                dir('task1-s3') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan - Task1') {
            steps {
                dir('task1-s3') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'p-17-tf-creds']
                    ]) {
                        sh '''
                            terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply - Task1') {
            steps {
                input message: 'Deploy Task-1 (S3)?', ok: 'Deploy'

                dir('task1-s3') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'p-17-tf-creds']
                    ]) {
                        sh '''
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Terraform Init - ECS') {
            steps {
                dir('task-2-ecs') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'p-17-tf-creds']
                    ]) {
                        sh '''
                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate - ECS') {
            steps {
                dir('task-2-ecs') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan - ECS') {
            steps {

                withCredentials([

                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'p-17-tf-creds'],

                    string(credentialsId: 'tf-api-key', variable: 'TF_VAR_api_key'),
                    string(credentialsId: 'tf-db-password', variable: 'TF_VAR_db_password'),
                    string(credentialsId: 'tf-db-host', variable: 'TF_VAR_db_host'),
                    string(credentialsId: 'tf-app-name', variable: 'TF_VAR_app_name')

                ]) {

                    dir('task-2-ecs') {
                        sh '''
                            terraform plan -out=tfplan
                            ls -lh
                        '''
                    }

                }
            }
        }

        stage('Terraform Apply - ECS') {
            steps {

                input message: 'Deploy ECS?', ok: 'Deploy'

                withCredentials([

                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'p-17-tf-creds'],

                    string(credentialsId: 'tf-api-key', variable: 'TF_VAR_api_key'),
                    string(credentialsId: 'tf-db-password', variable: 'TF_VAR_db_password'),
                    string(credentialsId: 'tf-db-host', variable: 'TF_VAR_db_host'),
                    string(credentialsId: 'tf-app-name', variable: 'TF_VAR_app_name')

                ]) {

                    dir('task-2-ecs') {
                        sh '''
                            terraform apply -auto-approve tfplan
                        '''
                    }

                }
            }
        }

        
    }

    post {

        success {
            echo "Deployment Successful"
        }

        failure {
            echo "Deployment Failed"
        }

        always {
            cleanWs()
        }

    }
}