package com.example.logprocessor;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.input.TextInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

public class LogProcessor extends Configured implements Tool {

    @Override
    public int run(String[] args) throws Exception {
        Configuration conf = getConf();

        // Skip the first argument if it's the class name
        int startIndex = 0;
        if (args.length > 0 && args[0].equals(this.getClass().getName())) {
            startIndex = 1;
        }

        // Calculate the actual number of path arguments
        int actualArgs = args.length - startIndex;

        if (actualArgs != 2) {
            System.err.println("Uso: LogProcessor <input_path> <output_path>");
            System.err.println("Ejemplo: LogProcessor hdfs://namenode:9000/input hdfs://namenode:9000/output");
            System.err.println("Argumentos recibidos: " + args.length);
            for (int i = 0; i < args.length; i++) {
                System.err.println("  arg[" + i + "]: " + args[i]);
            }
            return -1;
        }

        String inputPath = args[startIndex];
        String outputPath = args[startIndex + 1];

        // Configuración para MinIO si se usa S3
        if (inputPath.startsWith("s3a://") || outputPath.startsWith("s3a://")) {
            conf.set("fs.s3a.endpoint", "http://minio:9000");
            conf.set("fs.s3a.access.key", System.getenv("MINIO_ACCESS_KEY"));
            conf.set("fs.s3a.secret.key", System.getenv("MINIO_SECRET_KEY"));
            conf.set("fs.s3a.path.style.access", "true");
            conf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem");
        }

        // Configurar el job
        Job job = Job.getInstance(conf, "Log Processor - Análisis de Logs Web");
        job.setJarByClass(LogProcessor.class);

        // Configurar Mapper y Reducer
        job.setMapperClass(LogMapper.class);
        job.setCombinerClass(LogReducer.class);
        job.setReducerClass(LogReducer.class);

        // Tipos de salida
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        // Formatos de entrada/salida
        job.setInputFormatClass(TextInputFormat.class);
        job.setOutputFormatClass(TextOutputFormat.class);

        // Paths
        FileInputFormat.addInputPath(job, new Path(inputPath));
        FileOutputFormat.setOutputPath(job, new Path(outputPath));

        // Configuración dinámica de paralelismo
        // La configuración viene de getConf() que ya tiene los valores -D procesados
        int numReducers = Integer.parseInt(conf.get("mapreduce.job.reduces", "2"));
        job.setNumReduceTasks(numReducers);

        System.out.println("========================================");
        System.out.println("Iniciando Job de MapReduce");
        System.out.println("Input: " + inputPath);
        System.out.println("Output: " + outputPath);
        System.out.println("Número de Reducers: " + numReducers);
        System.out.println("========================================");

        // Ejecutar el job
        boolean success = job.waitForCompletion(true);

        if (success) {
            System.out.println("========================================");
            System.out.println("Job completado exitosamente!");
            System.out.println("Estadísticas:");
            System.out.println("- Maps ejecutados: " +
                job.getCounters().findCounter("org.apache.hadoop.mapreduce.JobCounter",
                    "TOTAL_LAUNCHED_MAPS").getValue());
            System.out.println("- Reduces ejecutados: " +
                job.getCounters().findCounter("org.apache.hadoop.mapreduce.JobCounter",
                    "TOTAL_LAUNCHED_REDUCES").getValue());
            System.out.println("- Registros procesados: " +
                job.getCounters().findCounter("org.apache.hadoop.mapreduce.TaskCounter",
                    "MAP_INPUT_RECORDS").getValue());
            System.out.println("========================================");
        } else {
            System.err.println("Job falló!");
        }

        return success ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new LogProcessor(), args);
        System.exit(exitCode);
    }
}
