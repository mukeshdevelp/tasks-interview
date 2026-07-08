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

        dir('task-2-ecs') {
        sh '''
            git clone https://github.com/iforimran9/ecs-task.git
        '''
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

        stage('Verify ECS Deployment') {
            steps {

                dir('task-2-ecs') {

                    script {

                        def alb = sh(
                            script: "terraform output -raw alb_dns_name",
                            returnStdout: true
                        ).trim()

                        echo "ALB DNS = ${alb}"

                        sh """
                            curl -i http://${alb}/health
                            echo
                            curl http://${alb}/config
                        """

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