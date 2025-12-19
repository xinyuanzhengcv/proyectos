## Proyecto de Trabajo de Fin de Master en Ciencia de Datos e Inteligencia de Negocio 

## Flujo de trabajo
El proyecto sigue un enfoque híbrido dividido en 3 fases, utilizando distintas herramientas según su fortaleza tecnica:

1. **Python**  
   Se utiliza para la limpieza y preparación inicial de los datos:
   - Carga y depuración de datos con pandas, numpy y modulos propios 
   - Tratamiento de valores nulos y outliers  
   - Estandarización y normalizacion de variables  
   - Generación de datasets limpios para el análisis posterior  

2. **R**  
   Se emplea para el análisis estadístico y el modelado predictivo:
   - Análisis exploratorio de datos (EDA)  
   - Transformación y selección de variables  
   - Entrenamiento de modelos de Machine Learning mediante `caret`  
   - Optimización de hiperparámetros (*hyperparameter tuning*)  
   - Validación cruzada y comparación de modelos  

   Modelos utilizados incluyen regresión lineal y regularizada (lasso, ridge), Redes Neuronales, Random Forest, XGBoost, LightGBM y Support Vector Machines (lineal, polinómico y radial).

3. **SAS Enterprise Miner**  
   Se utiliza para contrastar y validar algunos de los modelos de Machine Learning, con el objetivo de afianzar los resultados obtenidos en el análisis realizado en R.

Este enfoque permite aprovechar la flexibilidad de Python en procesos ETL, la potencia estadística de R para el modelado y ajuste de hiperparámetros, y la robustez de SAS como herramienta adicional de validación.
