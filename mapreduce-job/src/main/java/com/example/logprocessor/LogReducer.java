package com.example.logprocessor;

import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

import java.io.IOException;

public class LogReducer extends Reducer<Text, IntWritable, Text, IntWritable> {

    private IntWritable result = new IntWritable();

    @Override
    protected void reduce(Text key, Iterable<IntWritable> values, Context context)
            throws IOException, InterruptedException {

        int sum = 0;
        String keyStr = key.toString();

        // Para sesiones únicas, contar solo una vez
        if (keyStr.startsWith("session:")) {
            sum = 1; // Cada sesión cuenta como 1, independientemente de cuántas veces aparezca
        } else {
            // Para otras métricas, sumar todos los valores
            for (IntWritable val : values) {
                sum += val.get();
            }
        }

        result.set(sum);

        // Formatear la salida para mejor legibilidad
        Text formattedKey = new Text(formatOutputKey(keyStr, sum));
        context.write(formattedKey, result);

        // Actualizar contadores para estadísticas
        if (keyStr.startsWith("action:")) {
            context.getCounter("LogProcessor", "UNIQUE_ACTIONS").increment(1);
        } else if (keyStr.startsWith("page:")) {
            context.getCounter("LogProcessor", "UNIQUE_PAGES").increment(1);
        } else if (keyStr.startsWith("session:")) {
            context.getCounter("LogProcessor", "UNIQUE_SESSIONS").increment(1);
        }
    }

    private String formatOutputKey(String key, int count) {
        // Formatear la salida para que sea más legible
        String[] parts = key.split(":");
        if (parts.length >= 2) {
            String category = parts[0];
            String value = parts[1];

            switch (category) {
                case "action":
                    return String.format("Acción [%s]", value);
                case "page":
                    return String.format("Página [%s]", value);
                case "hour":
                    return String.format("Hora [%s:00]", value);
                case "session":
                    return String.format("Sesión [%s...]", value.substring(0, Math.min(8, value.length())));
                case "action_page":
                    String[] ap = value.split("_");
                    if (ap.length >= 2) {
                        return String.format("Acción-Página [%s en %s]", ap[0], ap[1]);
                    }
                    break;
                case "hour_action":
                    String[] ha = value.split("_");
                    if (ha.length >= 2) {
                        return String.format("Hora-Acción [%s:00 - %s]", ha[0], ha[1]);
                    }
                    break;
            }
        }
        return key;
    }
}
