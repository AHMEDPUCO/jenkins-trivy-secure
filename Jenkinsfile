pipeline {
    agent any

    environment {
        IMAGE_NAME = "ahmedpuco/myapp"
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        IMAGE_SCANNED_TAG = "scanned-latest"
    }

    stages {
        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }

        stage('Install Trivy') {
            steps {
                sh '''
                if ! command -v trivy &> /dev/null; then
                    echo "Installing Trivy..."
                    sudo apt-get update -y
                    sudo apt-get install wget apt-transport-https gnupg -y
                    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                    echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
                    sudo apt-get update
                    sudo apt-get install trivy -y
                else
                    echo "Trivy already installed."
                fi
                '''
            }
        }

        stage('Scan Image with Trivy') {
            steps {
                script {
                    try {
                        sh "trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed ${IMAGE_NAME}:${IMAGE_TAG}"
                        echo "✅ ¡Imagen segura! Sin vulnerabilidades críticas."
                        env.SCAN_PASSED = "true"
                    } catch (Exception e) {
                        echo "❌ ¡Vulnerabilidades críticas encontradas! Pipeline fallará."
                        env.SCAN_PASSED = "false"
                        throw e
                    }
                }
            }
        }

        stage('Push Scanned Image') {
            when {
                expression { env.SCAN_PASSED == "true" }
            }
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-creds') {
                        sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${IMAGE_SCANNED_TAG}"
                        docker.image("${IMAGE_NAME}:${IMAGE_TAG}").push()
                        docker.image("${IMAGE_NAME}:${IMAGE_SCANNED_TAG}").push()
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { env.SCAN_PASSED == "true" }
            }
            steps {
                sh '''
                # Asegúrate de que kubectl está disponible y configurado
                kubectl version --short

                # Generar deployment.yaml dinámicamente
                cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        security.verified: "true"   # <-- Etiqueta requerida por Kyverno
    spec:
      containers:
      - name: myapp
        image: ${IMAGE_NAME}:${IMAGE_SCANNED_TAG}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
EOF

                # Aplicar en Kubernetes
                kubectl apply -f deployment.yaml
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completado con éxito. Imagen escaneada y desplegada."
        }
        failure {
            echo "❌ Pipeline fallido. Revisa los logs de Trivy."
        }
    }
}
