pipeline {
    agent any

    environment {
        IMAGE_NAME = "ahmedpuco/myapp"  // ⬅️ ¡CAMBIA ESTO!
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        IMAGE_SCANNED_TAG = "scanned-latest"
        SCAN_PASSED = "false"  // Inicializado como false
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
                    // Usa Docker Pipeline Plugin — no requiere 'docker' CLI
                    env.BUILT_IMAGE = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                    echo "✅ Imagen construida: ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Verify trivy') {
            steps {
                sh 'trivy --version'

            }
        }

        stage('Scan Image with Trivy') {
            steps {
                script {
                    try {
                        // Escanea la imagen construida
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
                        // Push de la imagen original
                        env.BUILT_IMAGE.push()

                        // Taggear como "scanned-latest"
                        sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${IMAGE_SCANNED_TAG}"

                        // Obtener la imagen taggeada y hacer push
                        def scannedImage = docker.image("${IMAGE_NAME}:${IMAGE_SCANNED_TAG}")
                        scannedImage.push()

                        echo "✅ Imágenes subidas: ${IMAGE_NAME}:${IMAGE_TAG} y ${IMAGE_NAME}:${IMAGE_SCANNED_TAG}"
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
                # Verificar conexión con Kubernetes
                kubectl version --short

                # Generar deployment.yaml dinámicamente con la etiqueta de seguridad
                cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
meta
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    meta
      labels:
        app: myapp
        security.verified: "true"   # <-- Requerido por Kyverno
    spec:
      containers:
      - name: myapp
        image: ${IMAGE_NAME}:${IMAGE_SCANNED_TAG}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
meta
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

                # Aplicar manifiesto en Kubernetes
                kubectl apply -f deployment.yaml

                echo "✅ Despliegue en Kubernetes completado."
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 ¡Pipeline completado con éxito! Imagen escaneada y desplegada."
        }
        failure {
            echo "💥 Pipeline fallido. Revisa los logs de Trivy o las etapas anteriores."
        }
    }
}
