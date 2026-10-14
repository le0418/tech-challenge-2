pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '900160666800'
        EKS_CLUSTER = 'tech-challenge-2-eks'
        ECR_REPOSITORY = 'tech-challenge-2'
        HELM_RELEASE = 'flask-app'
        K8S_NAMESPACE = 'default'
        ECR_REGISTRY = '900160666800.dkr.ecr.us-east-1.amazonaws.com'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/le0418/tech-challenge-2.git'
            }
        }

        stage('Validate Source') {
            steps {
                sh '''
                    set -eu
                    test -f Dockerfile
                    test -f app/requirements.txt
                    test -f flask-chart/Chart.yaml
                    test -f flask-chart/values.yaml
                    grep -qi gunicorn app/requirements.txt
                    helm lint ./flask-chart
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = "build-${env.BUILD_NUMBER}"
                    env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                }
                sh '''
                    set -eu
                    docker build -t "$IMAGE_URI" .
                '''
            }
        }

        stage('Push to Amazon ECR') {
            steps {
                withCredentials([
                    string(credentialsId: 'tech-challenge-2-aws-access-key-id',
                           variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'tech-challenge-2-aws-secret-key',
                           variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        set +x
                        set -eu

                        export DOCKER_CONFIG="$(mktemp -d)"
                        trap 'rm -rf "$DOCKER_CONFIG"' EXIT

                        aws ecr get-login-password --region "$AWS_REGION" |
                            docker login --username AWS \
                            --password-stdin "$ECR_REGISTRY"

                        docker push "$IMAGE_URI"
                    '''
                }
            }
        }

        stage('Deploy to Amazon EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'tech-challenge-2-aws-access-key-id',
                           variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'tech-challenge-2-aws-secret-key',
                           variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        set +x
                        set -eu

                        export KUBECONFIG="$(mktemp)"
                        trap 'rm -f "$KUBECONFIG"' EXIT

                        aws eks update-kubeconfig \
                            --region "$AWS_REGION" \
                            --name "$EKS_CLUSTER" \
                            --kubeconfig "$KUBECONFIG"

                        helm upgrade "$HELM_RELEASE" ./flask-chart \
                            --namespace "$K8S_NAMESPACE" \
                            --values ./flask-chart/values.yaml \
                            --set-string image.repository="$ECR_REGISTRY/$ECR_REPOSITORY" \
                            --set-string image.tag="$IMAGE_TAG" \
                            --wait \
                            --timeout 15m

                        kubectl rollout status \
                            deployment/flask-app-flask-chart \
                            --namespace "$K8S_NAMESPACE" \
                            --timeout=600s

                        kubectl get deployment flask-app-flask-chart \
                            --namespace "$K8S_NAMESPACE"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
        }
        failure {
            echo 'CI/CD pipeline failed. Review the failed stage.'
        }
        always {
            sh '''
                if [ -n "${IMAGE_URI:-}" ]; then
                    docker image rm "$IMAGE_URI" >/dev/null 2>&1 || true
                fi
            '''
        }
    }
}
