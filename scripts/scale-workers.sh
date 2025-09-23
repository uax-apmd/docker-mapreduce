#!/bin/bash

# Script para escalar dinámicamente los workers de Hadoop

echo "================================================"
echo "       ESCALADOR DE WORKERS HADOOP"
echo "================================================"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <número_de_workers>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 4    # Escalar a 4 workers"
    echo "  $0 1    # Reducir a 1 worker"
    echo ""
    echo "Número actual de workers:"
    docker-compose ps datanode 2>/dev/null | grep -c "datanode" || echo "0"
    exit 1
fi

NUM_WORKERS=$1

if ! [[ "$NUM_WORKERS" =~ ^[0-9]+$ ]] || [ "$NUM_WORKERS" -lt 1 ]; then
    echo "Error: El número de workers debe ser un entero positivo"
    exit 1
fi

print_info "Escalando a $NUM_WORKERS workers..."

# Escalar usando docker-compose
docker-compose up -d --scale datanode=$NUM_WORKERS --no-recreate

if [ $? -eq 0 ]; then
    print_status "Escalado completado"

    # Esperar a que los nodos estén listos
    print_info "Esperando a que los nodos estén listos..."
    sleep 5

    # Mostrar estado actual
    echo ""
    echo "Estado actual del cluster:"
    echo "-------------------------"
    docker-compose ps | grep -E "(namenode|resourcemanager|datanode)"

    echo ""
    print_info "Workers activos: $NUM_WORKERS"
    print_status "Cluster listo para procesar jobs con $NUM_WORKERS workers"
else
    echo "Error al escalar los workers"
    exit 1
fi
