const express = require('express');
const Minio = require('minio');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Configurar cliente MinIO
const minioClient = new Minio.Client({
    endPoint: process.env.MINIO_ENDPOINT?.replace('http://', '').split(':')[0] || 'minio',
    port: 9000,
    useSSL: false,
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin123'
});

// Buffer para acumular logs
let logBuffer = [];
const BUFFER_SIZE = 100; // Guardar cada 100 logs
const FLUSH_INTERVAL = 30000; // O cada 30 segundos

// Función para generar un log
function generateLog(action, data = {}) {
    return {
        timestamp: new Date().toISOString(),
        sessionId: data.sessionId || uuidv4(),
        action: action,
        userAgent: data.userAgent || 'unknown',
        ip: data.ip || '127.0.0.1',
        page: data.page || '/',
        duration: data.duration || Math.floor(Math.random() * 5000),
        metadata: data.metadata || {}
    };
}

// Función para guardar logs en MinIO
async function flushLogs() {
    if (logBuffer.length === 0) return;

    const filename = `logs_${new Date().getTime()}_${uuidv4()}.json`;
    const content = JSON.stringify(logBuffer, null, 2);

    try {
        await minioClient.putObject('logs', filename, content, content.length, {
            'Content-Type': 'application/json'
        });
        console.log(`Guardados ${logBuffer.length} logs en MinIO: ${filename}`);
        logBuffer = [];
    } catch (err) {
        console.error('Error guardando logs en MinIO:', err);
    }
}

// Endpoint para recibir eventos del cliente
app.post('/api/log', async (req, res) => {
    const log = generateLog(req.body.action, {
        sessionId: req.body.sessionId,
        userAgent: req.headers['user-agent'],
        ip: req.ip,
        page: req.body.page,
        duration: req.body.duration,
        metadata: req.body.metadata
    });

    logBuffer.push(log);
    console.log('Log recibido:', log.action);

    // Flush si alcanzamos el tamaño del buffer
    if (logBuffer.length >= BUFFER_SIZE) {
        await flushLogs();
    }

    res.json({ success: true, logId: log.timestamp });
});

// Endpoint para generar logs de prueba
app.post('/api/generate-test-logs', async (req, res) => {
    const count = req.body.count || 100;
    const actions = ['page_view', 'button_click', 'form_submit', 'scroll', 'hover', 'search', 'download'];
    const pages = ['/', '/products', '/about', '/contact', '/cart', '/checkout'];

    for (let i = 0; i < count; i++) {
        const log = generateLog(
            actions[Math.floor(Math.random() * actions.length)],
            {
                sessionId: uuidv4(),
                page: pages[Math.floor(Math.random() * pages.length)],
                metadata: {
                    testData: true,
                    batchId: req.body.batchId || uuidv4()
                }
            }
        );
        logBuffer.push(log);
    }

    await flushLogs();
    res.json({ success: true, message: `Generados ${count} logs de prueba` });
});

// Flush periódico
setInterval(flushLogs, FLUSH_INTERVAL);

// Inicializar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor web-client ejecutándose en puerto ${PORT}`);
    console.log(`MinIO endpoint: ${process.env.MINIO_ENDPOINT}`);
});
