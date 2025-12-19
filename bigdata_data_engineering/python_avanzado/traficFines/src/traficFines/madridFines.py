from __future__ import annotations
from .cache import CacheURL, CacheError

from io import StringIO
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple

import pandas as pd
import requests
import time
from bs4 import BeautifulSoup
import matplotlib.pyplot as plt
import re



############################
# Constantes del portal
############################
RAIZ = "https://datos.madrid.es/"
ROOT = RAIZ
MADRID_FINES_URL = (
    "sites/v/index.jsp?vgnextoid=fb9a498a6bdb9410VgnVCM1000000b205a0aRCRD&vgnextchannel=374512b9ace9f310VgnVCM100000171f5a0aRCRD"
)

############################
# Excepción específica
############################
class MadridError(Exception):
    """Errores del módulo madridFines."""
    pass


############################
# Funciones
############################
def get_url(start_code: int, end_code: int) -> list:
    """
    Devuelve las URLs reales de los CSV asociadas a un rango de códigos de catálogo de multas.

    Ejemplo:
        get_url(150, 160) ->
        [
            "https://datos.madrid.es/egobfiles/MANUAL/210104/201706detalle.csv",
            "https://datos.madrid.es/egobfiles/MANUAL/210104/201707detalle.csv",
            ...
        ]
    """
    base_url = "https://datos.madrid.es/egob/catalogo/210104-{}-multas-circulacion-detalle.csv"
    urls_validas = []

    for code in range(start_code, end_code + 1):
        url_actual = base_url.format(code)
        print(f"Intentando descargar: {url_actual}")

        try:
            response = requests.get(url_actual, timeout=10)
            if response.status_code == 200:
                urls_validas.append(response.url)
                print(f"CSV encontrado: {response.url}")
            else:
                print(f"!!!No se encontró CSV para código {code} (status {response.status_code}).")

        except requests.exceptions.RequestException as e:
            print(f"Error de conexión para código {code}: {e}")

        # Pausa breve entre peticiones
        time.sleep(0.2)

    if not urls_validas:
        raise MadridError(f"No se encontraron CSV válidos en el rango {start_code}-{end_code}.")

    return urls_validas



############################
# Clase principal
############################
@dataclass
class MadridFines:
    """
    Clase para gestionar datos de multas de Madrid:
    - Descarga por meses con CacheURL.
    - Limpia y normaliza columnas.
    - Permite acumular varios meses/años en `data`.
    - Ofrece resúmenes y gráficos rápidos.
    """
    app_name: str = "traficFines"
    obsolescence: int = 7

    def __post_init__(self) -> None:
        self._cacheurl = CacheURL(app_name=self.app_name, obsolescence=self.obsolescence)
        self._data = pd.DataFrame()
        # enunciado pide (month, year)
        self._loaded: List[Tuple[int, int]] = []

    # ----- propiedades solo lectura -----
    @property
    def cacheurl(self) -> CacheURL:
        return self._cacheurl

    @property
    def data(self) -> pd.DataFrame:
        return self._data.copy()

    @property
    def loaded(self) -> List[Tuple[int, int]]:
        return list(self._loaded)

    # ----- métodos estáticos internos -----
    @staticmethod
    def load(year: int, month: int, cacheurl: CacheURL) -> pd.DataFrame:
        """
        Descarga (o lee de caché) el CSV del mes y lo devuelve como DataFrame crudo.
        Intenta detectar el separador automáticamente, usando ';' por defecto si falla.
        """
        url = get_url(year, month)
        try:
            csv_text = cacheurl.get(url, timeout=30)
        except CacheError as e:
            raise MadridError(f"No se pudo obtener el CSV {year}-{month:02d}: {e}") from e

        try:
            df = pd.read_csv(StringIO(csv_text), sep=None, engine="python")
        except Exception:
            df = pd.read_csv(StringIO(csv_text), sep=';')

        return df

    @staticmethod
    def clean(df: pd.DataFrame) -> None:
        """
        Limpieza básica (como en la Etapa 1):
        Modifica el DataFrame `df` directamente.
        """

        def norm(s: str) -> str:
            import re
            s = (
                s.strip()  # quita espacios al inicio y fin
                .replace(" ", "_")  # espacios → guiones bajos
                .replace("-", "_")  # guiones → guiones bajos
            )
            s = re.sub(r"[\x00-\x1F]", "", s)  # elimina caracteres de control (\x00, etc.)
            s = re.sub(r"_+", "_", s)  # colapsa guiones bajos consecutivos
            s = s.strip("_")  # elimina _ al inicio y final
            return s.upper()

        df.columns = [norm(c) for c in df.columns]

        # strip a columnas texto
        for c in df.select_dtypes(include=["object"]).columns:
            df[c] = df[c].astype(str).str.strip()

        # columnas numéricas
        def to_num(cols: list[str]) -> None:
            for c in cols:
                if c in df.columns:
                    df[c] = pd.to_numeric(df[c], errors="coerce")

        to_num(["VEL_CIRCULACION", "VEL_CIRCULA", "VEL_LIMITE", "COORDENADA_X", "COORDENADA_Y"])

        # construir FECHA si existen ANIO, MES y HORA
        if all(c in df.columns for c in ["ANIO", "MES", "HORA"]):
            try:
                hh = (
                    df["HORA"]
                    .astype(str)
                    .str.extract(r"(\d{1,2})", expand=False)
                    .astype("Int64")
                )
                df["FECHA"] = pd.to_datetime(
                    dict(year=df["ANIO"].astype("Int64"),
                         month=df["MES"].astype("Int64"),
                         day=1)
                ) + pd.to_timedelta(hh.fillna(0).astype(float), unit="h")
            except Exception:
                try:
                    df["FECHA"] = pd.to_datetime(
                        dict(year=df["ANIO"].astype("Int64"),
                             month=df["MES"].astype("Int64"),
                             day=1)
                    )
                except Exception:
                    pass


    # ----- API pública -----
    def add(self, year: int, month: int | None = None) -> None:
        """
        Agrega datos a `self._data`. Si `month` es None, añade los 12 meses del año.
        Evita duplicar meses ya cargados (usa `self._loaded` con tuplas (month, year)).
        """
        months = range(1, 13) if month is None else [int(month)]

        added = []
        for m in months:
            key = (m, year)
            if key in self._loaded:
                continue
            # carga y limpia
            df_raw = MadridFines.load(year, m, self.cacheurl)
            MadridFines.clean(df_raw)
            df_clean = df_raw

            # asegúrate de anotar ANIO/MES por si faltan
            if "ANIO" not in df_clean.columns:
                df_clean["ANIO"] = year
            if "MES" not in df_clean.columns:
                df_clean["MES"] = m

            # concatena
            self._data = pd.concat([self._data, df_clean], ignore_index=True)
            self._loaded.append(key)
            added.append(key)

        if not added and month is not None:
            # si pidió un mes concreto que ya estaba, no hacemos nada
            pass

    def fines_hour(self, fig_name: str) -> None:
        """
        Gráfico de líneas: nº de multas por HORA (una línea por (MES, ANIO)).
        Guarda la figura en `fig_name`.
        """
        if self._data.empty:
            raise MadridError("No hay datos cargados. Usa add(...) primero.")

        df = self._data.copy()

        # Aseguramos columna HORA
        if "HORA" not in df.columns:
            if "FECHA" in df.columns:
                df["HORA"] = pd.to_datetime(df["FECHA"]).dt.hour
            else:
                raise MadridError("No hay columna HORA ni FECHA para hacer el gráfico.")

        # tipos correctos
        df["HORA"] = pd.to_numeric(df["HORA"], errors="coerce")

        # agrupamos
        grp = df.groupby(["ANIO", "MES", "HORA"]).size().reset_index(name="MULTAS")

        plt.figure()
        for (yy, mm), sub in grp.groupby(["ANIO", "MES"]):
            sub = sub.sort_values("HORA")
            label = f"{int(mm):02d}/{int(yy)}"
            plt.plot(
                sub["HORA"], sub["MULTAS"],
                marker="o", linestyle="-", linewidth=1.5, markersize=4,
                label=label
            )

        plt.xlabel("Hora del día")
        plt.ylabel("Número de multas")
        plt.title("Evolución de multas por hora")
        plt.legend(loc="best")
        plt.tight_layout()
        Path(fig_name).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(fig_name)
        plt.close()

    def fines_calification(self) -> pd.DataFrame:
        """
        Tabla (ANIO, MES) x CALIFICACION con el nº de multas.
        Devuelve un DataFrame pivot estilo:
                    CALIFICACION   GRAVE   LEVE   MUY_GRAVE
            MES ANIO
            5   2019             61124  111017        747
        """
        if self._data.empty:
            raise MadridError("No hay datos cargados. Usa add(...) primero.")

        df = self._data.copy()
        if "CALIFICACION" not in df.columns:
            raise MadridError("No existe la columna CALIFICACION en los datos.")

        # asegurar tipos
        for col in ("ANIO", "MES"):
            if col not in df.columns:
                raise MadridError(f"Falta la columna {col} en los datos.")
            df[col] = pd.to_numeric(df[col], errors="coerce")

        tabla = (
            df.pivot_table(
                index=["MES", "ANIO"],
                columns="CALIFICACION",
                aggfunc="size",
                fill_value=0,
            )
            .sort_index()
        )

        return tabla.reset_index().set_index(["MES", "ANIO"])

    def total_payment(self) -> pd.DataFrame:
        """
        Calcula el importe total por (ANIO, MES) bajo dos escenarios:
        - TOTAL_MIN: todos pagan con descuento del 50% (pronto pago)
        - TOTAL_MAX: nadie aplica descuento (pagan el 100%)
        """
        if self._data.empty:
            raise MadridError("No hay datos cargados. Usa add(...) primero.")

        df = self._data.copy()

        # Asegurar que IMP_BOL sea numérica
        df["IMP_BOL"] = pd.to_numeric(df["IMP_BOL"], errors="coerce")

        # Agrupar por año y mes para sumar los importes
        base = (
            df.groupby(["ANIO", "MES"], dropna=False)["IMP_BOL"]
            .sum(min_count=1)
            .reset_index()
            .rename(columns={"IMP_BOL": "TOTAL_MAX"})
        )

        # TOTAL_MIN = 50% del importe total
        base["TOTAL_MIN"] = base["TOTAL_MAX"] * 0.5

        # Orden final
        base = base.sort_values(["ANIO", "MES"]).reset_index(drop=True)
        cols = ["ANIO", "MES", "TOTAL_MIN", "TOTAL_MAX"]

        return base[cols]

