# MapReduce Hadoop POC con Docker

## 📋 Descripción

Prueba de concepto completa de MapReduce con Hadoop usando Java, totalmente containerizada con Docker Compose. El sistema incluye:

- **Cliente Web**: Genera y envía logs de interacciones
- **MinIO**: Almacenamiento compatible con S3
- **Hadoop Cluster**: NameNode, ResourceManager y DataNodes escalables
- **MapReduce Job**: Procesa y analiza los logs

## 🚀 Inicio Rápido

### Requisitos
- Docker Desktop (Windows/Mac/Linux)
- Docker Compose v2+
- 8GB RAM mínimo
- 10GB espacio en disco

### Instalación y Ejecución

1. **Clonar o crear la estructura del proyecto**

2. **Iniciar el cluster completo:**
```bash
docker-compose up -d
```

3. **Verificar que todos los servicios están funcionando:**
```bash
docker-compose ps
```

4. **Acceder a las interfaces web:**
- Cliente Web: http://localhost:3000
- MinIO Console: http://localhost:9001 (admin/minioadmin123)
- Hadoop NameNode: http://localhost:9870
- YARN ResourceManager: http://localhost:8088

## 📊 Generación de Logs

### Opción 1: Interfaz Web
1. Abrir http://localhost:3000
2. Usar los botones para:
   - Iniciar tracking automático
   - Generar logs de prueba
   - Interactuar con los elementos

### Opción 2: API REST
```bash
# Generar 500 logs de prueba
curl -X POST http://localhost:3000/api/generate-test-logs \
  -H "Content-Type: application/json" \
  -d '{"count": 500}'
```

## ⚙️ Compilación del Job MapReduce

El JAR se compila automáticamente al iniciar, pero si necesitas recompilar:

```bash
docker-compose run --rm mapreduce-compiler mvn clean package
```

## 🔄 Ejecución del Job MapReduce

### Ejecutar en modo HDFS:
```bash
docker-compose exec job-runner bash /scripts/run-job.sh hdfs
```

### Ejecutar con datos de MinIO/S3:
```bash
docker-compose exec job-runner bash /scripts/run-job.sh s3
```

### Ejecutar demo con datos de ejemplo:
```bash
docker-compose exec job-runner bash /scripts/run-job.sh demo
```

### Especificar número de reducers:
```bash
docker-compose exec job-runner bash /scripts/run-job.sh hdfs -r 4
```

## 📈 Escalado Dinámico

### Escalar workers (DataNodes):
```bash
# Escalar a 5 workers
docker-compose exec job-runner bash /scripts/scale-workers.sh 5

# O directamente con docker-compose
docker-compose up -d --scale datanode=5
```

### Verificar el estado del cluster:
```bash
docker-compose ps | grep datanode
```

## 🔍 Monitoreo y Resultados

### Ver logs del procesamiento:
```bash
docker-compose logs -f job-runner
```

### Acceder a resultados en HDFS:
```bash
docker-compose exec job-runner hdfs dfs -ls /output/
docker-compose exec job-runner hdfs dfs -cat /output/*/part-r-00000
```

### Acceder a resultados en MinIO:
1. Ir a http://localhost:9001
2. Login: minioadmin / minioadmin123
3. Navegar al bucket "output"

## 📁 Estructura del Proyecto

```
mapreduce-hadoop-poc/
├── docker-compose.yml          # Orquestación de contenedores
├── .env                        # Variables de entorno
├── hadoop/                     # Configuración de Hadoop
│   ├── Dockerfile
│   ├── config/*.xml           # Configuraciones Hadoop
│   └── entrypoint.sh
├── web-client/                 # Aplicación generadora de logs
│   ├── server.js
│   └── public/index.html
├── mapreduce-job/             # Job MapReduce en Java
│   ├── pom.xml
│   └── src/main/java/...
└── scripts/                   # Scripts de utilidad
    ├── run-job.sh
    └── scale-workers.sh
```

## 🛠️ Comandos Útiles

### Gestión del Cluster

```bash
# Iniciar todo
docker-compose up -d

# Detener todo
docker-compose down

# Ver logs de un servicio
docker-compose logs -f [servicio]

# Reiniciar un servicio
docker-compose restart [servicio]

# Limpiar todo (incluyendo volúmenes)
docker-compose down -v
```

### Operaciones HDFS

```bash
# Listar archivos
docker-compose exec job-runner hdfs dfs -ls /

# Crear directorio
docker-compose exec job-runner hdfs dfs -mkdir /test

# Copiar archivo local a HDFS
docker-compose exec job-runner hdfs dfs -put /local/file /hdfs/path

# Ver contenido de archivo
docker-compose exec job-runner hdfs dfs -cat /path/to/file
```

### Operaciones MinIO

```bash
# Listar buckets
docker-compose exec job-runner aws --endpoint-url=http://minio:9000 s3 ls

# Listar contenido de bucket
docker-compose exec job-runner aws --endpoint-url=http://minio:9000 s3 ls s3://logs/

# Descargar archivo
docker-compose exec job-runner aws --endpoint-url=http://minio:9000 s3 cp s3://logs/file.json /tmp/
```

## 🔧 Configuración Avanzada

### Modificar recursos de YARN
Editar `.env`:
```env
YARN_MEMORY_MB=4096
YARN_VCORES=4
```

### Cambiar replicación HDFS
Editar `hadoop/config/hdfs-site.xml`:
```xml
<property>
    <name>dfs.replication</name>
    <value>3</value>
</property>
```

## 📊 Métricas del Job

El job procesa los logs y genera estadísticas sobre:
- Acciones realizadas por los usuarios
- Páginas más visitadas
- Distribución por hora del día
- Sesiones únicas
- Combinaciones acción-página

## 🐛 Troubleshooting

### El job no encuentra los logs
- Verificar que hay logs en MinIO: http://localhost:9001
- Generar logs desde http://localhost:3000

### Error de memoria en workers
- Aumentar memoria Docker Desktop
- Reducir número de workers
- Ajustar YARN_MEMORY_MB en .env

### Contenedores no inician
```bash
# Ver logs detallados
docker-compose logs [servicio]

# Reiniciar desde cero
docker-compose down -v
docker-compose up -d
```

### Job falla con error de clase
```bash
# Recompilar el JAR
docker-compose run --rm mapreduce-compiler mvn clean package
```

## 📝 Notas

- El sistema está optimizado para desarrollo/testing
- Los datos persisten en volúmenes Docker
- El cluster se auto-configura al iniciar
- No requiere Java instalado en el host
- Compatible con Windows, Mac y Linux

## 🎯 Casos de Uso de la POC

1. **Análisis de logs en tiempo real**
2. **Procesamiento batch de eventos**
3. **Agregación de métricas**
4. **Demo de escalabilidad Hadoop**
5. **Testing de jobs MapReduce**

## 🚦 Estado de Servicios

Para verificar que todo está funcionando:

```bash
# Verificar servicios
docker-compose exec job-runner bash -c "
echo 'Verificando servicios...'
nc -zv namenode 9870 && echo '✓ NameNode OK'
nc -zv resourcemanager 8088 && echo '✓ ResourceManager OK'
nc -zv minio 9000 && echo '✓ MinIO OK'
nc -zv web-client 3000 && echo '✓ Web Client OK'
"
```

## 📚 Recursos Adicionales

- [Hadoop Documentation](https://hadoop.apache.org/docs/stable/)
- [MinIO Documentation](https://docs.min.io/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

**Desarrollado como POC de MapReduce con Hadoop en Docker**
