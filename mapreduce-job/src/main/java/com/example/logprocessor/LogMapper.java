package com.example.logprocessor;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.IOException;
import java.util.Iterator;

public class LogMapper extends Mapper<LongWritable, Text, Text, IntWritable> {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Text outputKey = new Text();
    private final IntWritable outputValue = new IntWritable(1);

    @Override
    protected void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {

        String line = value.toString().trim();

        // Saltar líneas vacías
        if (line.isEmpty()) {
            return;
        }

        try {
            // Intentar parsear como JSON
            JsonNode root = objectMapper.readTree(line);

            // Si es un array de logs, procesar cada uno
            if (root.isArray()) {
                for (JsonNode logEntry : root) {
                    processLogEntry(logEntry, context);
                }
            }
            // Si es un objeto único
            else if (root.isObject()) {
                processLogEntry(root, context);
            }
            // Si el línea comienza con '[' o '{', intentar procesar el archivo completo
            else if (line.startsWith("[")) {
                // Leer todo el contenido como un array JSON
                JsonNode array = objectMapper.readTree(line);
                for (JsonNode logEntry : array) {
                    processLogEntry(logEntry, context);
                }
            }

        } catch (Exception e) {
            // Log del error pero continuar procesando
            System.err.println("Error procesando línea: " + e.getMessage());
            context.getCounter("LogProcessor", "PARSE_ERRORS").increment(1);
        }
    }

    private void processLogEntry(JsonNode logEntry, Context context)
            throws IOException, InterruptedException {

        // Extraer campos del log
        String action = getFieldValue(logEntry, "action", "unknown");
        String page = getFieldValue(logEntry, "page", "/");
        String sessionId = getFieldValue(logEntry, "sessionId", "no-session");
        String timestamp = getFieldValue(logEntry, "timestamp", "");

        // Extraer hora del timestamp (formato: HH)
        String hour = "unknown";
        if (!timestamp.isEmpty() && timestamp.contains("T")) {
            try {
                String timePart = timestamp.split("T")[1];
                hour = timePart.substring(0, 2);
            } catch (Exception e) {
                // Ignorar errores de parsing
            }
        }

        // Emitir diferentes métricas

        // 1. Conteo por acción
        outputKey.set("action:" + action);
        context.write(outputKey, outputValue);

        // 2. Conteo por página
        outputKey.set("page:" + page);
        context.write(outputKey, outputValue);

        // 3. Conteo por hora del día
        outputKey.set("hour:" + hour);
        context.write(outputKey, outputValue);

        // 4. Combinación acción-página
        outputKey.set("action_page:" + action + "_" + page);
        context.write(outputKey, outputValue);

        // 5. Sesiones únicas (se deduplicará en el reducer)
        outputKey.set("session:" + sessionId);
        context.write(outputKey, outputValue);

        // 6. Actividad por hora y acción
        outputKey.set("hour_action:" + hour + "_" + action);
        context.write(outputKey, outputValue);

        // Incrementar contador de logs procesados
        context.getCounter("LogProcessor", "LOGS_PROCESSED").increment(1);
    }

    private String getFieldValue(JsonNode node, String field, String defaultValue) {
        if (node.has(field) && !node.get(field).isNull()) {
            return node.get(field).asText();
        }
        return defaultValue;
    }
}
