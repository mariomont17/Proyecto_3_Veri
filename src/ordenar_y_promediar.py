import pandas as pd

def ordenar_y_promediar(csv_path, columna_ordenacion, archivo_nuevo):
    # Cargar el archivo CSV en un DataFrame de pandas
    df = pd.read_csv(csv_path)

    # Ordenar el DataFrame por la columna especificada
    df = df.sort_values(by=columna_ordenacion)

    # Elimina las filas duplicadas
    df_promediado = df.drop_duplicates()

    # Guardar el resultado ordenado y promediado en un nuevo archivo CSV
    resultado_path = archivo_nuevo
    df_promediado.to_csv(resultado_path, index=False)

    print(f"Archivo CSV resultante guardado en: {resultado_path}")

# Ordenar csv de retardos promedio 
archivo_csv = "reporte_retardo_prom.csv"
columna_ordenacion = "Profundidad"
nuevo_archivo = "rpt_retardo_prom.csv"
ordenar_y_promediar(archivo_csv, columna_ordenacion, nuevo_archivo)

# Ordenar csv de bw promedio 
archivo_csv = "reporte_bw_prom.csv"
columna_ordenacion = "Profundidad"
nuevo_archivo = "rpt_bw_prom.csv"
ordenar_y_promediar(archivo_csv, columna_ordenacion, nuevo_archivo)

# Ordenar csv de bw maximo 
archivo_csv = "reporte_bw_max.csv"
columna_ordenacion = "Profundidad"
nuevo_archivo = "rpt_bw_max.csv"
ordenar_y_promediar(archivo_csv, columna_ordenacion, nuevo_archivo)

# Ordenar csv de bw minimo 
archivo_csv = "reporte_bw_min.csv"
columna_ordenacion = "Profundidad"
nuevo_archivo = "rpt_bw_min.csv"
ordenar_y_promediar(archivo_csv, columna_ordenacion, nuevo_archivo)