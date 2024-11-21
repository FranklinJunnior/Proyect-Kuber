#!/bin/bash

# Función para verificar errores
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "Docker no está instalado. Por favor, instala Docker Desktop para Mac."
    exit 1
else
    echo "Docker está instalado, verificando el servicio..."
    if ! docker info >/dev/null 2>&1; then
        echo "No se puede conectar a Docker. Por favor, asegúrate de que Docker Desktop esté ejecutándose."
        exit 1
    fi
    echo "Docker está funcionando correctamente"
fi

# Verificar si Minikube está instalado
if ! command -v minikube &> /dev/null; then
    echo "Minikube no está instalado. Procediendo a instalar..."
    brew install minikube || check_error "No se pudo instalar Minikube."
else
    echo "Minikube ya está instalado."
fi

# Verificar si kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo "kubectl no está instalado. Procediendo a instalar..."
    brew install kubectl || check_error "No se pudo instalar kubectl."
else
    echo "kubectl ya está instalado."
fi

# Iniciar Minikube con configuración optimizada
if ! minikube status &> /dev/null; then
    echo "Iniciando Minikube..."
    minikube start --driver=hyperkit \
        --memory=2048 \
        --cpus=2 \
        --disk-size=20g || check_error "No se pudo iniciar Minikube."
else
    echo "Minikube ya está iniciado."
fi

# Clonar el repositorio y aplicar configuraciones
if [ ! -d "Proyect-Kuber" ]; then
    echo "Clonando el repositorio..."
    git clone https://github.com/FranklinJunnior/Proyect-Kuber.git || check_error "No se pudo clonar el repositorio."
fi

cd Proyect-Kuber/kubernetes || check_error "No se pudo acceder al directorio kubernetes."

# Verificar si los directorios existen antes de aplicar configuraciones
if [ -d "deployments" ] && [ -d "services" ] && [ -d "monitoring" ]; then
    # Aplicar configuraciones de Kubernetes
    echo "Aplicando configuraciones de Kubernetes..."
    kubectl apply -f deployments/ || check_error "Error al aplicar deployments."
    kubectl apply -f services/ || check_error "Error al aplicar services."
    kubectl apply -f monitoring/ || check_error "Error al aplicar monitoring."

    # Esperar a que los servicios estén listos
    echo "Esperando a que los servicios estén listos..."
    kubectl wait --for=condition=ready pod -l app=grafana --timeout=300s
    kubectl wait --for=condition=ready pod -l app=prometheus --timeout=300s
    kubectl wait --for=condition=ready pod -l app=vote-app --timeout=300s

    # Mostrar URLs de acceso
    echo "URLs de acceso:"
    for service in "grafana" "prometheus" "vote-app"; do
        URL=$(minikube service $service --url)
        echo "$service está disponible en: $URL"
    done
else
    echo "Error: No se encontraron los directorios necesarios en el repositorio."
    echo "Estructura esperada:"
    echo "- deployments/"
    echo "- services/"
    echo "- monitoring/"
    exit 1
fi

# Guardar información importante
echo "Guardando información de la instalación..."
cat > installation_info.txt << EOF
Fecha de instalación: $(date)
Versión de Minikube: $(minikube version)
Versión de kubectl: $(kubectl version --client)
Versión de Docker: $(docker --version)

URLs de acceso:
$(kubectl get svc -o wide)

Estado de los pods:
$(kubectl get pods -o wide)

Notas adicionales:
- Para acceder a los servicios, use los URLs proporcionados arriba
- Para detener minikube: minikube stop
- Para iniciar minikube: minikube start
EOF

echo "Instalación completada. Revise installation_info.txt para más detalles."
echo "
Instrucciones post-instalación:
1. Para acceder a los servicios, use los URLs mostrados arriba
2. Para detener el cluster: minikube stop
3. Para iniciar el cluster: minikube start
4. Para eliminar el cluster: minikube delete
"
