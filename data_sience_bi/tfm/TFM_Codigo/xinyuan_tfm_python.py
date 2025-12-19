
# Librerias
import os

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from ydata_profiling import ProfileReport
import unidecode
import funciones

##################################################################################################################################
## CONFIGURACIÓN PREVIA
##################################################################################################################################

# === 1. Establecer la ruta raíz (la carpeta donde está este script) ===

try:
    # Si se ejecuta como script
    base_dir = os.path.dirname(os.path.abspath(__file__))
except NameError:
    # Si se ejecuta por consola interactiva (como R o Jupyter)
    base_dir = os.getcwd()

print("Ruta base del proyecto:", base_dir)

# === 2. Subcarpeta con datos crudos ===
ruta_datos = os.path.join(base_dir, "datos")
print(ruta_datos)

# Configuración de la consola Python
pd.set_option('display.max_columns', None)     # Mostrar todas las columnas
pd.set_option('display.width', 150)            # No cortar el ancho de la línea
pd.set_option('display.max_colwidth', None)    # Mostrar contenido completo de cada celda

##################################################################################################################################
## 1. IMPORTAR DATOS Y PREPARACION DEL DATASET FINAL
##################################################################################################################################

# Importar datos meteorologicos

# Leer los archivos desde la carpeta 'datos'
df1 = funciones.txt_to_df(os.path.join(ruta_datos, "1sem2022.txt"))
df2 = funciones.txt_to_df(os.path.join(ruta_datos, "2sem2022.txt"))
df3 = funciones.txt_to_df(os.path.join(ruta_datos, "1sem2023.txt"))
df4 = funciones.txt_to_df(os.path.join(ruta_datos, "2sem2023.txt"))

# Concatenar
tiempo_meteorologico_madrid = pd.concat([df1, df2, df3, df4], ignore_index=True)

# Guardar el archivo final en la raíz del proyecto
df_tiempo = os.path.join(ruta_datos, "madrid_tiempo_22_23.csv")
tiempo_meteorologico_madrid.to_csv(df_tiempo, index=False)

# Descripcion de las variables
df_metadatos=funciones.txt_to_df(os.path.join(ruta_datos, "metadatos.txt"),encoding='latin1')
print(pd.DataFrame(df_metadatos['campos'].tolist())[['id', 'descripcion']])


# Variables escogidos para el trabajo (dataset meteorologico final)
tiempo_22_23 = tiempo_meteorologico_madrid[['fecha', 'tmed', 'prec', 'velmedia', 'sol', 'hrMedia']].copy()


# --------------------------------------------------------------------------------------------------------------------------------

# Importar datos calendarios
calendario = pd.read_csv(os.path.join(ruta_datos, "calendario.csv"), sep=";")

# Extraer periodo temporal
calendario['Dia'] = pd.to_datetime(calendario['Dia'], format='%d/%m/%Y')
calendario_22_23 = calendario[(calendario['Dia'] >= '2022-01-01') & (calendario['Dia'] <= '2023-12-31')]

# Variables escogidos
calendario_22_23 = calendario_22_23[['Dia', 'Dia_semana', 'laborable / festivo / domingo festivo']]

# Transformacion de datos y asignación de nueva variable (dataset calendario final)
calendario_22_23['tipo_dia'] = calendario_22_23.apply(funciones.completar_tipo_dia, axis=1)
calendario_22_23 = calendario_22_23[['Dia', 'Dia_semana', 'tipo_dia']]
calendario_22_23.rename(columns={'Dia': 'fecha'}, inplace=True)

# --------------------------------------------------------------------------------------------------------------------------------

# Importar datos de la demanda de metro madrid 2022 - 2023
demanda_metro_madrid = pd.read_excel(os.path.join(ruta_datos, "Demanda Histórica Metro de Madrid 2022-2023.xlsx"))
demanda_metro_madrid.describe(include = 'all')

# Agrupar por fecha y nombre de estacion (sumar las entradas de todos los accesos para la misma estacion)
demanda_22_23 = demanda_metro_madrid.groupby(['JORNADA', 'NOMBRE'])['SUM(VIAJES)'].sum().reset_index()

# Pivotear para obtener formato ancho
demanda_22_23 = demanda_22_23.pivot(index='JORNADA', columns='NOMBRE', values='SUM(VIAJES)')
demanda_22_23 = demanda_22_23.reset_index()
demanda_22_23.columns.name = None

demanda_22_23.rename(columns={'JORNADA': 'fecha'}, inplace=True)


# Revision de los tipos de variables
print(tiempo_22_23.dtypes)
tiempo_22_23['fecha'] = pd.to_datetime(tiempo_22_23['fecha'], format='%Y-%m-%d')


print(calendario_22_23.dtypes)
calendario_22_23['Dia_semana'] = calendario_22_23['Dia_semana'].astype('category')
calendario_22_23['tipo_dia'] = calendario_22_23['tipo_dia'].astype('category')


print(demanda_22_23.dtypes)

##################################################################################################################################

# Generar el dataset completo (calendario + clima + demanda)

# Paso 1: Unir calendario + clima
datos_completo = pd.merge(calendario_22_23, tiempo_22_23, on='fecha', how='left')

# Paso 2: Unir con demanda
datos_completo = pd.merge(datos_completo, demanda_22_23, on='fecha', how='left')


datos_completo.describe(include = 'all')

datos_completo_22_23 = os.path.join(base_dir, "datos_completo_22_23.csv")
datos_completo.to_csv(datos_completo_22_23, index=False)

##################################################################################################################################
## MAPA DE LAS ESTACIONES DE METRO
##################################################################################################################################

# Leer coordenadas de estaciones
coordenadas_metro = pd.read_excel(os.path.join(ruta_datos, "coordenadas_estaciones_metro.xlsx"))

# Crear dataset de entradas totales por estación (suma de 2 años)
demanda_total = demanda_metro_madrid.groupby("NOMBRE", as_index=False)["SUM(VIAJES)"].sum()
demanda_total.rename(columns={"NOMBRE": "Nombre", "SUM(VIAJES)": "Entradas"}, inplace=True)

# Mapa general de estaciones con demanda - Visualización de la distribución espacial de las estaciones en 22-23
funciones.dibujar_mapa_estaciones(
    df_demanda=demanda_total,
    df_coords=coordenadas_metro,
    output_html="mapa_estaciones_total.html",
    variable="Entradas",
    radio=2
)

##################################################################################################################################
## MAPA DE LAS ESTACIONES A 3KM DE CHAMARTIN
##################################################################################################################################

estacion_objetivo = "Chamartín"

# Calcular distancias desde Chamartín
distancias = funciones.calcular_distancias_estaciones(estacion_objetivo, coordenadas_metro)

# Seleccionar estaciones dentro de 3 km
estaciones_3km = distancias[distancias['Distancia_km'] <= 3] # Radio de análisis espacial: 3 km alrededor de la estación de Chamartín

# Unir con demanda
demanda_estaciones_3km = pd.merge(estaciones_3km, demanda_total, on="Nombre", how="left")

# Dibujar mapa de estaciones cercanas con círculo de 3 km
funciones.dibujar_mapa_estaciones(
    df_demanda=demanda_estaciones_3km[["Nombre", "Entradas"]],
    df_coords=estaciones_3km,
    output_html="mapa_chamartin_3km.html",
    variable="Entradas",
    radio=4,
    estacion_objetivo=estacion_objetivo,
    radio_circulo_km=3
)

##################################################################################################################################

# Generar el dataset filtrado para las estaciones a 3km de Chamartin (calendario + clima + demanda 3km)

# Paso 1: Unir calendario + clima
datos_filtrado = pd.merge(calendario_22_23, tiempo_22_23, on='fecha', how='left')

# Paso 2: Filtrar columnas de demanda solo de las estaciones dentro de 3 km
estaciones_filtradas = ['fecha'] + demanda_estaciones_3km['Nombre'].tolist()
demanda_estaciones_filtrada = demanda_22_23[estaciones_filtradas].copy()

# Paso 3: Unir con demanda filtrada
datos_filtrado = pd.merge(datos_filtrado, demanda_estaciones_filtrada, on='fecha', how='left')

# Guardar CSV (dataset final para comenzar el trabajo)
datos_filtrado_22_23 = os.path.join(base_dir, "datos_filtrado_22_23.csv")
datos_filtrado.to_csv(datos_filtrado_22_23, index=False)



##################################################################################################################################
## 2. LIMPIEZA Y DEPURTACION DEL DATASET
##################################################################################################################################

'''Al ejecutar las lineas de codigos hasta aqui, se tiene que limpiar la consola, y empezar desde aqui par aque se pueda mostrar 
las graficas posteriores, de no ser asi, da error. Se debe ejecutar de nuevo las librerias, y configuracion previa antes de 
 seguir por aqui'''

# Importar datos calendarios
datos_filtrado_22_23 = pd.read_csv(os.path.join(base_dir, "datos_filtrado_22_23.csv"), sep=",")

datos=datos_filtrado_22_23.copy()

# Informe completo de la estructura del dataset

profile = ProfileReport(datos, title="Resumen Exploratorio", explorative=True)
profile.to_file("reporte_exploratorio.html")

# Exploracion inicial
datos.describe(include='all')
datos.info()

# --------------------------------------------------------------------------------------------------------------------------------

# Establecer los tipos de datos de cada variable (las estaciones se cambiara a 'int' despues de imputar)
datos['fecha'] = pd.to_datetime(datos['fecha'])
datos['Dia_semana'] = datos['Dia_semana'].astype('category')
datos['tipo_dia'] = datos['tipo_dia'].astype('category')

datos.info()

# Esta variable lo pasamos a 'object' para sacarlo del grupo y trabajar con ella luego de forma separada
datos['prec'] = datos['prec'].astype('object')


# --------------------------------------------------------------------------------------------------------------------------------

# Detección y tratamiento de valores atípicos

# Seleccionar variables numéricas (excepto fecha y categóricas)
var_numeric = datos.select_dtypes(include=['float64', 'int64']).columns.tolist()

# Detectar y reemplazar atípicos por NA
outliers_dict = {}
for col in var_numeric:
    datos[col], n_outliers = funciones.detectar_atipicos_y_reemplazar_na(datos[col])
    outliers_dict[col] = n_outliers / len(datos)

# Mostrar proporción de atípicos por variable
outliers_proporcion = pd.Series(outliers_dict)
print(outliers_proporcion.sort_values(ascending=False))

# --------------------------------------------------------------------------------------------------------------------------------

# Mostrar filas con NA por variable, solo con la fecha y la variable afectada
variables_con_na = datos.columns[datos.isna().any()].tolist()

for var in variables_con_na:
    df_na = datos.loc[datos[var].isna(), ['fecha', var]]
    if not df_na.empty:
        print(f"\n Filas con NA en la variable: {var} ({len(df_na)} observaciones)")
        display(df_na)


# Imputar valores con 1 NA usando la media entre el valor anterior y posterior
datos = funciones.imputar_na_con_vecinos(datos, "velmedia")
datos = funciones.imputar_na_con_vecinos(datos, "sol")
datos = funciones.imputar_na_con_vecinos(datos, "Santiago Bernabéu")

# Imputar valores con 33 NA (aprox 1 mes) usando la media del mismo día de la semana en el mes anterior y posterior.
datos = funciones.imputar_na_con_dia_equivalente(datos, "Concha Espina")
datos = funciones.imputar_na_con_dia_equivalente(datos, "Cruz del Rayo")

# La variable Pinar de Rey tiene demasiados NAs durante largo periodo, siendo inviable imputarlo por otros valores, por lo que
# elimina del dataset.
datos.drop(columns=["Pinar del Rey"], inplace=True)

datos.describe(include='all')
datos.info()

# --------------------------------------------------------------------------------------------------------------------------------

# Transformar las NA de prec en 0
datos['prec'] = pd.to_numeric(datos['prec'], errors='coerce')
datos["prec"] = datos["prec"].fillna(0)

# Crear variable categórica
datos['prec_cat'] = datos['prec'].apply(funciones.clasificar_precipitacion)
datos['prec_cat'] = datos['prec_cat'].astype('category')


# Crear dummies para 'prec_cat' eliminando la categoría de referencia (prec_baja)
dummies_prec = pd.get_dummies(datos['prec_cat'], prefix='', prefix_sep='')



# Unir al dataset original y eliminar la original
datos = pd.concat([datos, dummies_prec], axis=1)
datos.drop(columns=['prec', 'prec_cat'], inplace=True)

# --------------------------------------------------------------------------------------------------------------------------------

# Establecer orden de categorías (para controlar cuál será la referencia)
datos['Dia_semana'] = datos['Dia_semana'].cat.reorder_categories(
    ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'],
    ordered=False
)

datos['tipo_dia'] = datos['tipo_dia'].cat.reorder_categories(
    ['festivo', 'laborable', 'fin_de_semana'], ordered=False
)

# Generar dummies
datos = pd.get_dummies(datos, columns=['Dia_semana', 'tipo_dia'])

# Convertir todas las columnas booleanas a enteros (0/1)
bool_cols = datos.select_dtypes(include='bool').columns
datos[bool_cols] = datos[bool_cols].astype(int)

datos.describe(include='all')
datos.info()
print(datos)

# --------------------------------------------------------------------------------------------------------------------------------

# Lista de columnas que no deben redondearse
columnas_excluir = ['tmed', 'velmedia', 'sol']

# Detectar columnas float64 que no estén en la lista de exclusión
columnas_redondear = [col for col in datos.select_dtypes(include='float64').columns if col not in columnas_excluir]

# Redondear
datos[columnas_redondear] = datos[columnas_redondear].round(0)

# --------------------------------------------------------------------------------------------------------------------------------

# Insertar variables lags para periodo de tiempo -1, -2 y -7

datos = datos.sort_values('fecha')

# Crear las columnas de lag
datos['lag_1'] = datos['Chamartín'].shift(1)
datos['lag_2'] = datos['Chamartín'].shift(2)
datos['lag_7'] = datos['Chamartín'].shift(7)

# Mostrar los primeros valores para revisar
print(datos[['Chamartín', 'lag_1', 'lag_2', 'lag_7']].head(10))

datos = datos.dropna(subset=['lag_1', 'lag_2', 'lag_7'])


# Seleccionamos solo columnas numéricas excepto 'Chamartín'
var_objetivo = 'Chamartín'
variables_numericas = datos.select_dtypes(include=['float64', 'int64']).columns
variables_predictoras = [col for col in variables_numericas if col != var_objetivo]

# Generar los gráficos de dispersión en grupos de 9 variables
for i in range(0, len(variables_predictoras), 9):
    subset = variables_predictoras[i:i+9]
    fig, axes = plt.subplots(nrows=3, ncols=3, figsize=(15, 12))
    #fig.suptitle(f"Nube de puntos vs {var_objetivo}", fontsize=16)

    for j, var in enumerate(subset):
        row, col = divmod(j, 3)
        ax = axes[row][col]
        ax.scatter(datos[var], datos[var_objetivo], alpha=0.6)
        ax.set_xlabel(var)
        ax.set_ylabel(var_objetivo)

    # Desactivar los subgráficos vacíos si hay menos de 9 variables
    for k in range(len(subset), 9):
        row, col = divmod(k, 3)
        axes[row][col].axis('off')

    # Ajustar con el objeto fig en lugar de plt
    fig.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.show()

# --------------------------------------------------------------------------------------------------------------------------------

# Renombrar columnas: minúsculas, sin tildes, espacios por guiones bajos
datos.columns = [
    unidecode.unidecode(col).lower().replace(' ', '_') for col in datos.columns
]

# Quitamos las columnas de los dummies de referencia
datos = datos.drop(columns=['prec_baja', 'dia_semana_lunes', 'tipo_dia_festivo'])

# Guardar datos en *csv
ruta_csv = os.path.join(base_dir, "datos_std.csv")
datos.to_csv(ruta_csv, index=False)

# Guardar como archivo Parquet
datos.to_parquet("datos_std.parquet", index=False)


# --------------------------------------------------------------------------------------------------------------------------------
from sklearn.preprocessing import StandardScaler


# Seleccionar columnas numéricas que se deben estandarizar (todas menos fecha y dummies)
columnas_estandarizar = [col for col in datos.select_dtypes(include=['float64', 'int64']).columns if col != 'fecha']


# Aplicar estandarización
scaler = StandardScaler()
datos[columnas_estandarizar] = scaler.fit_transform(datos[columnas_estandarizar])

print(datos.dtypes)


# Guardar datos en *csv
ruta_csv = os.path.join(base_dir, "datos.csv")
datos.to_csv(ruta_csv, index=False)

# Guardar como archivo Parquet
datos.to_parquet("datos.parquet", index=False)

