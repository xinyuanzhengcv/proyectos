
# Proyecto: Trafico de Multas en Madrid

Este proyecto implementa un paquete Python llamado **traficFines** que permite descargar, cachear y analizar los datos abiertos de multas de circulación del Ayuntamiento de Madrid.


## Formato de trabajo 
- Los test se realiza mediante una simulación sin acceder a los datos reales del url. 
- En el notebook de validacion_paquete.ipynb se realiza la consulta al url, de la fecha correspondiente al 06/2017 hasta 06/2025. Pero para probar las funciones de los modulos se ha cogido solamente el 12/2024 para la generacion de grafica, tablas, etc. 

## Instalación de las dependencias desde requirements.txt
pip install -r requirements.txt

## Ejecución de los tests y cobertura
pytest -vv -s --cov=src/traficFines --cov-report=term-missing

## Estructura del proyecto

```plaintext
traficFines/
│
├── notebooks/
│   ├── enunciado.ipynb              # Documento con el enunciado de la práctica
│   ├── validacion_paquete.ipynb     # Notebook de validación funcional sin mocks
│
├── src/
│   └── traficFines/
│       ├── __init__.py
│       ├── cache.py                 # Módulo de gestión de caché (Cache, CacheURL)
│       └── madridFines.py           # Módulo principal de análisis de multas
│
├── tests/
│   ├── test_cache.py                # Tests del módulo cache.py
│   └── test_madridFines.py          # Tests del módulo madridFines.py
│
├── README.md                        # Descripción del proyecto y guía de uso
├── requirements.txt                 # Dependencias del entorno
└── pyproject.toml                   # Configuración del paquete y dependencias

```
