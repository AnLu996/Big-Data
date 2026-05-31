USE lab04;

DROP TABLE IF EXISTS documentos_con_archivo;

CREATE EXTERNAL TABLE documentos_con_archivo (
    linea STRING
)
STORED AS TEXTFILE
LOCATION '/user/hadoop/lab04/textos';