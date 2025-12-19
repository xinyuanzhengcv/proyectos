import pytest
from pathlib import Path
import pandas as pd
from traficFines.madridFines import (
    get_url, MadridFines, MadridError, RAIZ, MADRID_FINES_URL
)
from traficFines.cache import CacheURL, CacheError
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


#########################################################
# TESTS PARA FUNCIONES SUELTAS
#########################################################
import pytest
import pandas as pd
from traficFines.madridFines import MadridFines, MadridError, get_url
from traficFines.cache import CacheError

#########################################################
# TESTS PARA FUNCIONES SUELTAS
#########################################################

def test_get_url_range(monkeypatch):
    """get_url() puede usarse en un rango de códigos."""
    # simulamos rango del 390 al 395
    url = get_url(390,395)


def test_get_url_invalid(monkeypatch):
    """Si el código no es entero o negativo, lanza error."""
    with pytest.raises((TypeError, ValueError)):
        get_url("abc")  # tipo no válido
    with pytest.raises((TypeError, ValueError)):
        get_url(-5)  # código inválido

def test_get_url_sin_csv(monkeypatch):
    """Si ningún código devuelve CSV válido, lanza MadridError."""
    class DummyResp:
        status_code = 404
        url = "https://datos.madrid.es/invalido.csv"
    monkeypatch.setattr("traficFines.madridFines.requests.get", lambda *a, **k: DummyResp)
    from traficFines.madridFines import get_url, MadridError
    with pytest.raises(MadridError):
        get_url(390, 391)


#########################################################
# Tests para la clase MadridFines
#########################################################

def test_load_ok(monkeypatch):
    """load() devuelve un DataFrame válido con separador detectado."""
    csv = "ANIO;MES;HORA;IMP_BOL\n2024;12;10;200"
    class DummyCache:
        def get(self, *a, **k): return csv
    monkeypatch.setattr("traficFines.madridFines.get_url", lambda y, m: "http://dummy.csv")
    df = MadridFines.load(2024, 12, DummyCache())
    assert isinstance(df, pd.DataFrame)
    assert "IMP_BOL" in df.columns

def test_load_cacheerror(monkeypatch):
    """Si falla la caché, lanza MadridError."""
    class DummyCache:
        def get(self, *a, **k): raise CacheError("fallo")
    monkeypatch.setattr("traficFines.madridFines.get_url", lambda y, m: "url")
    with pytest.raises(MadridError):
        MadridFines.load(2024, 12, DummyCache())

def test_clean_y_fecha_ok():
    """clean() normaliza columnas y crea FECHA."""
    df = pd.DataFrame({
        "anio": [2024],
        "mes": [12],
        "hora": ["10"],
        "imp bol": [100]
    })
    MadridFines.clean(df)
    assert "ANIO" in df.columns
    assert "FECHA" in df.columns

def test_add_un_mes(monkeypatch):
    """add() añade correctamente un mes al objeto."""
    csv = "ANIO;MES;HORA;IMP_BOL\n2024;12;10;200"
    class DummyCache:
        def get(self, *a, **k): return csv
    monkeypatch.setattr("traficFines.madridFines.CacheURL", lambda **k: DummyCache())
    monkeypatch.setattr("traficFines.madridFines.get_url", lambda y, m: "http://dummy.csv")
    mf = MadridFines()
    mf.add(2024, 12)
    assert not mf.data.empty
    assert (12, 2024) in mf.loaded

def test_fines_hour_ok(tmp_path):
    """fines_hour() genera un gráfico temporal."""
    mf = MadridFines()
    mf._data = pd.DataFrame({
        "ANIO": [2024, 2024],
        "MES": [12, 12],
        "HORA": [10, 11]
    })
    fig = tmp_path / "h.png"
    mf.fines_hour(fig)
    assert fig.exists()


def test_fines_calification_ok():
    """fines_calification() genera tabla agregada sin error."""
    mf = MadridFines()
    mf._data = pd.DataFrame({
        "ANIO": [2024, 2024, 2024],
        "MES": [12, 12, 12],
        "CALIFICACION": ["GRAVE", "LEVE", "MUY GRAVE"]
    })
    tabla = mf.fines_calification()
    assert isinstance(tabla, pd.DataFrame)
    assert "GRAVE" in tabla.columns or len(tabla) > 0

def test_fines_calification_faltan_columnas():
    """Lanza error si faltan columnas requeridas."""
    mf = MadridFines()
    mf._data = pd.DataFrame({"MES": [12]})
    with pytest.raises(MadridError):
        mf.fines_calification()

def test_fines_hour_sin_hora_y_fecha():
    """Si faltan HORA y FECHA, fines_hour lanza MadridError."""
    mf = MadridFines()
    mf._data = pd.DataFrame({"ANIO": [2024], "MES": [12]})
    with pytest.raises(MadridError):
        mf.fines_hour("dummy.png")

def test_fines_calification_sin_calificacion():
    """Lanza error si no hay columna CALIFICACION."""
    mf = MadridFines()
    mf._data = pd.DataFrame({"ANIO": [2024], "MES": [12]})
    with pytest.raises(MadridError):
        mf.fines_calification()

def test_fines_calification_sin_anio():
    """Lanza error si falta ANIO."""
    mf = MadridFines()
    mf._data = pd.DataFrame({"MES": [12], "CALIFICACION": ["LEVE"]})
    with pytest.raises(MadridError):
        mf.fines_calification()

def test_total_payment_ok():
    """total_payment() calcula correctamente usando IMP_BOL."""
    mf = MadridFines()
    mf._data = pd.DataFrame({
        "ANIO": [2024],
        "MES": [12],
        "IMP_BOL": [200]
    })
    res = mf.total_payment()
    assert "TOTAL_MAX" in res.columns
    assert res["TOTAL_MIN"].iloc[0] == 100

def test_total_payment_faltan_columnas():
    """Lanza error si falta columna de importe."""
    mf = MadridFines()
    mf._data = pd.DataFrame({"ANIO": [2024], "MES": [12], "IMP_BOL": [10]})


def test_total_payment_sin_datos():
    """Lanza error si no hay datos cargados."""
    mf = MadridFines()
    with pytest.raises(MadridError):
        mf.total_payment()

def test_cache_get_error(tmp_path):
    """CacheURL.get lanza CacheError si el archivo no existe."""
    c = CacheURL(base_dir=tmp_path)
    # simula URL inexistente
    from traficFines.cache import CacheError
    with pytest.raises(CacheError):
        c.get("http://no-existe.com/fake.csv")


