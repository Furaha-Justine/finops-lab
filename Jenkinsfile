pipeline {
    agent any

    environment {
        AWS_REGION              = 'eu-west-1'
        ECR_REPOSITORY          = 'fincorp-app'
        CODEARTIFACT_DOMAIN     = 'fincorp-domain'
        CODEARTIFACT_REPOSITORY = 'fincorp-internal'
        AWS_ACCOUNT_ID          = '976193229864'
        IMAGE_TAG               = "${env.GIT_COMMIT}"
    }

    stages {
        stage('Authenticate npm against CodeArtifact') {
            steps {
                dir('fincorp-app') {
                    withCredentials([usernamePassword(
                        credentialsId: 'aws-jenkins-creds',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )]) {
                        sh '''
                            aws codeartifact login \
                              --tool npm \
                              --domain "$CODEARTIFACT_DOMAIN" \
                              --domain-owner "$AWS_ACCOUNT_ID" \
                              --repository "$CODEARTIFACT_REPOSITORY" \
                              --region "$AWS_REGION"
                        '''
                    }
                }
            }
        }

        stage('Install dependencies') {
            steps {
                dir('fincorp-app') {
                    sh 'npm ci'
                }
            }
        }

        stage('Run tests') {
            steps {
                dir('fincorp-app') {
                    sh 'npm test'
                }
            }
        }

        stage('Build Docker image') {
            steps {
                dir('fincorp-app') {
                    sh 'docker build --provenance=false --sbom=false -t "$ECR_REPOSITORY:$IMAGE_TAG" .'
                }
            }
        }

        // Gate: build fails here if any HIGH/CRITICAL vulnerability with an
        // available fix is found, before the image is ever pushed to ECR.
        // --ignore-unfixed excludes CVEs with no vendor patch yet (nothing a
        // rebuild can remediate); those still show up in the ECR native scan
        // findings artifact below for audit visibility.
        stage('Scan image for vulnerabilities (Trivy)') {
            steps {
                sh '''
                    trivy image \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      --exit-code 1 \
                      --timeout 15m \
                      "$ECR_REPOSITORY:$IMAGE_TAG"
                '''
            }
        }

        stage('Push immutable image to ECR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
                        aws ecr get-login-password --region "$AWS_REGION" \
                          | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                        docker tag "$ECR_REPOSITORY:$IMAGE_TAG" "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
                        docker push "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
                    '''
                }
            }
        }

        // Defense-in-depth + audit trail: ECR's own scan-on-push runs
        // independently of the Trivy gate above. Record its findings as a
        // build artifact for compliance/audit purposes.
        stage('Record ECR native scan findings (audit trail)') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        aws ecr wait image-scan-complete \
                          --repository-name "$ECR_REPOSITORY" \
                          --image-id imageTag=$IMAGE_TAG \
                          --region "$AWS_REGION" || true
                        aws ecr describe-image-scan-findings \
                          --repository-name "$ECR_REPOSITORY" \
                          --image-id imageTag=$IMAGE_TAG \
                          --region "$AWS_REGION" \
                          --output json | tee ecr-scan-findings.json
                    '''
                }
                archiveArtifacts artifacts: 'ecr-scan-findings.json', fingerprint: true
            }
        }
    }

    post {
        always {
            sh 'docker logout "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" || true'
        }
    }
}
