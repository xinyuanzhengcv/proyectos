## Fotocasa – Web Scraping + MySQL + Power BI

Notebook en Python para extraer ofertas de alquiler desde Fotocasa y construir un flujo completo de captura → almacenamiento → análisis -> visualización.

El proceso comienza automatizando la navegación web con Selenium (Chrome) y `undetected_chromedriver`: acceso a la web, aceptación de cookies y definición de criterios de búsqueda. Se configura la búsqueda para **alquiler en “Madrid Capital, Madrid”** y se aplican filtros como **precio máximo 1000€**, **tipo de vivienda “Plantas intermedias”** y **fecha de publicación “Última semana”**, gestionando además pop-ups como “Crear Alerta”.

Para la extracción se implementan funciones que hacen scroll para cargar resultados (`scroll_page`) y parsean el HTML con BeautifulSoup (`extract_articles`). Se obtienen y limpian campos como **título**, **ubicación**, **precio**, **tamaño (m²)**, **habitaciones**, **baños**, **calefacción**, **aire acondicionado**, **planta** y **URL del anuncio**. Se realiza scraping de varias páginas, se concatenan los resultados y se exportan a **Excel** (`viviendas_fotocasa.xlsx`) con `openpyxl`.

Posteriormente, los datos se cargan en **MySQL**: creación de base de datos (`db_fotocasa`), creación de tabla (`ofertas_inmobiliarias`) e inserción masiva de registros con `mysql.connector`, gestionando nulos para evitar errores de carga. Para consultar los datos de forma cómoda se usa SQLAlchemy (`create_engine`) y `pandas.read_sql`.

Finalmente, se realiza un EDA básico con pandas (descriptivos, conteos de ubicaciones, ordenación por precio) y visualizaciones con Matplotlib y Seaborn: **distribución de precios**, **precio medio por número de habitaciones** y **relación precio–tamaño**.

## Librerías principales
- Automatización y scraping: `selenium`, `undetected_chromedriver`, `bs4 (BeautifulSoup)`
- Procesamiento de datos: `pandas`, `numpy`
- Exportación: `openpyxl`
- Base de datos: `mysql.connector`, `sqlalchemy` (y driver `pymysql` en la cadena de conexión)
- Visualización: `matplotlib`, `seaborn`

# Visualización de dashboard 
Se puede acceder al archivo de Power BI o dentro del pdf, en la ultima diapositiva.
