# Laboratorios de Big Data

Este repositorio contiene los laboratorios desarrollados para el curso de **Big Data**.  
El objetivo principal es aplicar herramientas y técnicas de procesamiento de datos a gran escala, trabajando con archivos de texto reales y de tamaño considerable.

## Dataset utilizado

Para el desarrollo de los laboratorios se utiliza el dataset:

**Central Bank Speeches Dataset**  
Disponible en Kaggle:  
https://www.kaggle.com/datasets/magnushansson/central-bank-speeches

Este dataset fue construido a partir de discursos emitidos por directivos y juntas de bancos centrales afiliados al **Bank for International Settlements (BIS)**.

El conjunto de datos fue utilizado en el paper:

**Evolution of topics in central bank speech communication**  
Autor: **Magnus Hansson**  
Correo: hansson.carl.magnus@gmail.com  
Sitio web: www.magnushansson.xyz

## Contexto del dataset

El dataset contiene discursos de bancos centrales correspondientes a **122 instituciones** afiliadas al BIS, cubriendo el periodo desde:

**1997-01-07 hasta 2025-11-12**

Los discursos fueron recolectados desde la página web del BIS mediante técnicas de scraping. Según la descripción del dataset, los archivos PDF fueron descargados usando el módulo `requests`, procesados con `BeautifulSoup` y posteriormente convertidos de `.pdf` a `.txt` usando `textract`.

## Importancia del dataset para Big Data

Este dataset es adecuado para los laboratorios del curso porque contiene una gran cantidad de archivos en formato .txt, lo que permite trabajar con escenarios cercanos al procesamiento de datos masivos.

Su importancia radica en que permite aplicar tareas como:

- Carga de archivos en sistemas distribuidos.
- Procesamiento de texto a gran escala.
- Limpieza y normalización de datos.
- Conteo de palabras.
- Análisis de frecuencia de términos.
- Consultas con Hive.
- Procesamiento con Hadoop y MapReduce.
- Preparación de datos para análisis posteriores.

Además, al estar compuesto por discursos reales de bancos centrales, el dataset permite trabajar con información textual extensa, estructurada por fechas y proveniente de una fuente económica relevante.

## Objetivo del repositorio

El objetivo de este repositorio es organizar los laboratorios del curso de Big Data, documentando los pasos realizados para cargar, procesar, analizar y consultar datos textuales utilizando herramientas del ecosistema Big Data.


## Tecnologías utilizadas

Entre las tecnologías y herramientas utilizadas en los laboratorios se pueden incluir:

- Hadoop
- HDFS
- MapReduce
- Hive
- Python
- Bash
- AWS EMR o entornos distribuidos similares
- Archivos .txt como fuente principal de datos
