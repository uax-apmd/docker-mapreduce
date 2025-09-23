#!/bin/bash

# Script para ejecutar el job de MapReduce

echo "================================================"
echo "         EJECUTOR DE JOB MAPREDUCE"
echo "================================================"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Configurar variables de entorno para MinIO si no están definidas
export MINIO_ENDPOINT=${MINIO_ENDPOINT:-http://minio:9000}
export MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-minioadmin}
export MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-minioadmin123}
export AWS_ACCESS_KEY_ID=$MINIO_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$MINIO_SECRET_KEY
export AWS_DEFAULT_REGION=us-east-1

print_info "Configuración MinIO:"
print_info "  Endpoint: $MINIO_ENDPOINT"
print_info "  Access Key: $MINIO_ACCESS_KEY"

# Verificar parámetros
if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <modo> [opciones]"
    echo ""
    echo "Modos disponibles:"
    echo "  hdfs    - Procesar logs desde HDFS"
    echo "  s3      - Procesar logs desde MinIO/S3"
    echo "  demo    - Ejecutar demo con datos de ejemplo"
    echo ""
    echo "Opciones:"
    echo "  -r <num>  - Número de reducers (default: 2)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 hdfs"
    echo "  $0 s3 -r 4"
    echo "  $0 demo"
    exit 1
fi

MODE=$1
REDUCERS=2

# Procesar opciones
shift
while getopts "r:" opt; do
    case $opt in
        r)
            REDUCERS=$OPTARG
            ;;
        *)
            echo "Opción no válida: -$OPTARG"
            exit 1
            ;;
    esac
done

print_info "Modo: $MODE"
print_info "Número de Reducers: $REDUCERS"

# Configurar paths según el modo
case $MODE in
    hdfs)
        INPUT_PATH="hdfs://namenode:9000/input"
        OUTPUT_PATH="hdfs://namenode:9000/output/job_$(date +%Y%m%d_%H%M%S)"

        print_status "Preparando HDFS..."

        # Configurar AWS CLI para MinIO
        export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY:-minioadmin}
        export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY:-minioadmin123}
        export AWS_DEFAULT_REGION=us-east-1

        # Crear directorio de entrada si no existe
        hdfs dfs -mkdir -p /input

        # Copiar logs de MinIO a HDFS
        print_info "Descargando logs de MinIO..."
        mkdir -p /tmp/logs
        aws --endpoint-url=$MINIO_ENDPOINT s3 sync s3://logs /tmp/logs/

        print_info "Copiando logs a HDFS..."
        hdfs dfs -put -f /tmp/logs/* /input/

        print_status "Logs copiados a HDFS"
        ;;

    s3)
        INPUT_PATH="s3a://logs/"
        OUTPUT_PATH="s3a://output/job_$(date +%Y%m%d_%H%M%S)"

        print_status "Usando MinIO directamente como fuente"
        ;;

    demo)
        print_status "Generando datos de demostración..."

        # Crear datos de ejemplo
        cat > /tmp/demo_logs.json << 'EOF'
[
{"timestamp":"2024-01-01T10:15:30Z","sessionId":"session1","action":"page_view","page":"/home"},
{"timestamp":"2024-01-01T10:16:00Z","sessionId":"session1","action":"button_click","page":"/home"},
{"timestamp":"2024-01-01T10:17:00Z","sessionId":"session2","action":"page_view","page":"/products"},
{"timestamp":"2024-01-01T11:20:00Z","sessionId":"session2","action":"form_submit","page":"/contact"},
{"timestamp":"2024-01-01T11:25:00Z","sessionId":"session3","action":"page_view","page":"/about"},
{"timestamp":"2024-01-01T12:30:00Z","sessionId":"session3","action":"download","page":"/resources"},
{"timestamp":"2024-01-01T14:45:00Z","sessionId":"session4","action":"search","page":"/products"},
{"timestamp":"2024-01-01T14:46:00Z","sessionId":"session4","action":"button_click","page":"/products"},
{"timestamp":"2024-01-01T15:00:00Z","sessionId":"session5","action":"page_view","page":"/home"},
{"timestamp":"2024-01-01T15:01:00Z","sessionId":"session5","action":"scroll","page":"/home"}
]
EOF

        # Subir a HDFS
        hdfs dfs -mkdir -p /demo/input
        hdfs dfs -put -f /tmp/demo_logs.json /demo/input/

        INPUT_PATH="hdfs://namenode:9000/demo/input"
        OUTPUT_PATH="hdfs://namenode:9000/demo/output_$(date +%Y%m%d_%H%M%S)"

        print_status "Datos de demo cargados"
        ;;

    *)
        print_error "Modo no reconocido: $MODE"
        exit 1
        ;;
esac

# Verificar que el JAR existe
JAR_PATH="/shared/jars/target/log-processor-1.0.0.jar"
if [ ! -f "$JAR_PATH" ]; then
    print_error "JAR no encontrado en $JAR_PATH"
    print_info "Ejecute primero: docker-compose up mapreduce-compiler"
    exit 1
fi

print_status "JAR encontrado: $JAR_PATH"

# Limpiar output anterior si existe
if [ "$MODE" == "hdfs" ] || [ "$MODE" == "demo" ]; then
    hdfs dfs -rm -r -f ${OUTPUT_PATH} 2>/dev/null
elif [ "$MODE" == "s3" ]; then
    aws --endpoint-url=$MINIO_ENDPOINT s3 rm ${OUTPUT_PATH} --recursive 2>/dev/null
fi

# Ejecutar el job
print_info "Iniciando Job de MapReduce..."
print_info "Input: $INPUT_PATH"
print_info "Output: $OUTPUT_PATH"
print_info "Reducers: $REDUCERS"
echo "----------------------------------------"

# Ejecutar con configuración de reducers
hadoop jar $JAR_PATH \
    -Dmapreduce.job.reduces=$REDUCERS \
    com.example.logprocessor.LogProcessor \
    "$INPUT_PATH" \
    "$OUTPUT_PATH"

JOB_STATUS=$?

echo "----------------------------------------"

if [ $JOB_STATUS -eq 0 ]; then
    print_status "Job completado exitosamente!"

    # Mostrar resultados
    print_info "Mostrando resultados:"
    echo ""

    if [ "$MODE" == "s3" ]; then
        # Configurar AWS CLI para MinIO
        export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY:-minioadmin}
        export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY:-minioadmin123}
        export AWS_DEFAULT_REGION=us-east-1

        # Descargar resultados de S3
        aws --endpoint-url=$MINIO_ENDPOINT s3 cp ${OUTPUT_PATH}/part-r-00000 /tmp/output.txt
        cat /tmp/output.txt | head -20
        print_info "Resultados guardados en MinIO: ${OUTPUT_PATH}"
    else
        # Mostrar resultados de HDFS
        hdfs dfs -cat ${OUTPUT_PATH}/part-r-* | head -20
        print_info "Resultados guardados en HDFS: ${OUTPUT_PATH}"
    fi

    echo ""
    print_status "Proceso completado!"
else
    print_error "El job falló con código: $JOB_STATUS"
    exit $JOB_STATUS
fi
