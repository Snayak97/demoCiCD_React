pipeline {
    agent any
    environment {
        COMPOSE_FILE = 'docker-compose.yml'
        
        SONAR_HOME   = tool 'sonar'
        
        GIT_URL      = "https://github.com/Snayak97/DemoCICD_react.git"
        GIT_BRANCH   = "main"
        VERSION      = ""
        
        APP_NAME     = "demo_reactapp"
        DOCKERHUB_REPO  = "snayak97/soumya1"
        
        DEV_PORT            = "5174"
        STAGING_PORT        = "5175"
        PROD_PORT           = "80"
        
        DEV_CONTAINER       = "${APP_NAME}-dev"
        STAGING_CONTAINER   = "${APP_NAME}-staging"
        PROD_CONTAINER      = "${APP_NAME}-prod"
        
        DEV_SERVER      = "ubuntu@ec2-54-83-66-74.compute-1.amazonaws.com"
        STAGING_SERVER  = "ubuntu@ec2-3-95-18-173.compute-1.amazonaws.com"
        PROD_SERVER     = "ubuntu@ec2-44-220-158-39.compute-1.amazonaws.com"
        
        PREVIOUS_VERSION    = ""
        DEPLOYMENT_STATUS   = "PENDING"
    }
    
    
    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        ansiColor('xterm')
    }
    parameters {
        choice(
            name: 'DEPLOY_TO',
            choices: ['development', 'staging', 'production', 'all'],
            description: 'Select deployment target'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip tests (not recommended for prod)'
        )
        booleanParam(
            name: 'FORCE_DEPLOY',
            defaultValue: false,
            description: 'Force deployment even if quality gate fails'
        )
    }

    stages {
        stage('Initialize Pipeline') {
            steps {
                script {
                    
                    try {
                        PREVIOUS_VERSION = sh(
                            script: "docker images ${DOCKERHUB_REPO} --format '{{.Tag}}' | head -1",
                            returnStdout: true
                        ).trim()
                        echo " Previous version detected: ${PREVIOUS_VERSION}"
                    } catch (Exception e) {
                        echo " No previous version found"
                        PREVIOUS_VERSION = "none"
                    }
                }
            }
        }
        stage('Cleanup Workspace') {
            steps {
                script {
                    echo "========== CLEANUP START =========="

                    try {
                        deleteDir()
                        echo "Workspace cleaned"

                        sh '''
                          which docker || { echo "Docker not installed"; exit 1; }
                          docker compose down -v || echo "No running containers"
                        '''
                    } catch (err) {
                        echo "Cleanup failed: ${err}"
                        error("Stopping pipeline — cleanup stage failed.")
                    }

                    echo "========== CLEANUP END =========="
                }
            }
        }
        stage('Checkout Code') {
            steps {
                script {
                    echo "========== CHECKOUT START =========="

                    retry(3) {
                        try {
                            checkout([
                                $class: 'GitSCM',
                                branches: [[name: "*/${GIT_BRANCH}"]],
                                userRemoteConfigs: [[url: "${GIT_URL}"]]
                            ])
                            echo "Checkout successful"
                            
                        } catch (err) {
                            echo "Git checkout failed: ${err}"
                            echo "Retrying in 3 seconds..."
                            sleep 3
                            throw err
                        }
                    }
                    if (env.GIT_COMMIT) {
                        env.VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                    } else {
                        env.VERSION = "${env.BUILD_NUMBER}-latest"
                    }

                    echo "========== CHECKOUT END =========="
                }
            }
        }
        stage('Debug Workspace') {
            steps {
                script {
                    echo "========== WORKSPACE DEBUG START =========="

                    try {
                        sh '''
                          echo "---- Directory ----"
                          pwd

                          echo "---- Files ----"
                          ls -la

                          echo "---- Checking Required Files ----"
                          cat index.html || echo "index.html not found"
                          echo "---- Git Status ----"
                          git status || echo "Not a git repo"
                        '''
                        echo "Workspace validation passed"
                    } catch (err) {
                        echo "Workspace validation failed: ${err}"
                        error("Stopping pipeline — required files missing.")
                    }

                    echo "========== WORKSPACE DEBUG END =========="
                }
            }
        }
        stage('Install Dependencies') {
            steps {
        script {
            echo "========== INSTALL DEPENDENCIES START =========="

            try {
                sh '''
                  which node || { echo "Node.js not installed"; exit 1; }
                  node -v
                  npm -v
                '''
                sh '''
                  npm ci --prefer-offline
                '''

                echo "Dependencies installed successfully (using npm ci --prefer-offline)"
            } catch (err) {
                echo "Dependency installation failed: ${err}"
                error("Stopping pipeline — Install Dependencies failed.")
            }

            echo "========== INSTALL DEPENDENCIES END =========="
        }
    }
        }
        stage("unit test"){
            steps{
                echo "unit test running"
            }
        }
        stage('Build React App') {
            steps {
        script {
            echo "========== BUILD START =========="

            try {
                sh '''
                  echo "Building React app..."
                  npm run build
                '''
                echo "React app built successfully"
            } catch (err) {
                echo "Build failed: ${err}"
                error("Stopping pipeline — Build React App failed.")
            }

            echo "========== BUILD END =========="
        }
    }
        }
        
        stage('Docker Login') {
            steps {
        script {
            echo "========== DOCKER LOGIN START =========="
            try {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                 usernameVariable: 'DOCKERHUB_USER',
                                                 passwordVariable: 'DOCKERHUB_PASS')]) {
                    sh '''
                        which docker >/dev/null 2>&1 || { echo "Docker not installed"; exit 1; }
                        echo "Logging into Docker Hub..."
                        echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
                        docker info | grep Username
                    '''
                }
                echo "Docker login successful."
            } catch (err) {
                echo "Docker login failed: ${err}"
                error("Stopping pipeline — Docker Login stage failed.")
            }
            echo "========== DOCKER LOGIN END =========="
        }
    }
        }
        stage('Docker Build') {
    steps {
        script {
            echo "========== DOCKER BUILD START =========="
            try {
                sh """
                    which docker >/dev/null 2>&1 || { echo 'Docker is not installed'; exit 1; }

                    echo "Exporting environment variables for docker-compose..."
                    export VERSION=${env.VERSION}
                    export DOCKERHUB_REPO=${env.DOCKERHUB_REPO}
                    export CONTAINER_NAME=${env.APP_NAME}-container
                    export HOST_PORT=80

                    echo "Building Docker image using docker-compose..."
                    docker compose -f ${env.COMPOSE_FILE} build --no-cache

                    echo "Tagging image for DockerHub..."
                    docker tag ${env.DOCKERHUB_REPO}:${env.VERSION} ${env.DOCKERHUB_REPO}:${env.VERSION}

                    echo "Cleaning unused images..."
                    docker image prune -f
                """
            } catch (err) {
                echo "Docker build failed: ${err}"
                error("Stopping pipeline — Docker Build stage failed.")
            }
            echo "========== DOCKER BUILD END =========="
        }
    }
}
        stage('Check Docker Image Existence') {
    steps {
        script {
            echo "========== CHECK DOCKER IMAGE START =========="
            try {
                if (!env.VERSION) {
                    error("VERSION is not set. Cannot check image existence.")
                }

                // Check if image exists on Docker Hub
                def response = sh(
                    script: """
                        TOKEN=\$(curl -s -H "Content-Type: application/json" \
                            -X POST -d '{"username":"$DOCKERHUB_USER","password":"$DOCKERHUB_PASS"}' \
                            https://hub.docker.com/v2/users/login/ | jq -r .token)

                        curl -s -H "Authorization: JWT \$TOKEN" \
                            https://hub.docker.com/v2/repositories/${DOCKERHUB_REPO}/tags/${env.VERSION}/ | jq -r .name
                    """,
                    returnStdout: true
                ).trim()

                if (response == env.VERSION) {
                    echo "Docker image ${DOCKERHUB_REPO}:${env.VERSION} already exists. Skipping build?"
                    // Optionally set a flag to skip Docker build
                    env.SKIP_DOCKER_BUILD = "true"
                } else {
                    echo "Docker image ${DOCKERHUB_REPO}:${env.VERSION} does not exist. Will build."
                    env.SKIP_DOCKER_BUILD = "false"
                }

            } catch (err) {
                echo "Error checking Docker image existence: ${err}"
                echo "Proceeding with Docker build."
                env.SKIP_DOCKER_BUILD = "false"
            }
            echo "========== CHECK DOCKER IMAGE END =========="
        }
    }
}





    }
}
