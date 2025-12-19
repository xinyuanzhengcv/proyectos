from pathlib import Path
import sys
import pytest
from traficFines.cache import Cache, CacheURL, CacheError


############################
# Tests para Cache
############################

def test_init_creates_cache_dir(tmp_path: Path):
    """Comprueba que al crear la caché se genera correctamente el directorio y los atributos."""
    c = Cache(app_name="tests_cache", obsolescence=7, base_dir=tmp_path)
    assert c.app_name == "tests_cache"
    assert c.obsolescence == 7
    d = Path(c.cache_dir)
    assert d.exists() and d.is_dir()


def test_init_fails_if_base_is_a_file(tmp_path: Path):
    """Si el directorio base es un archivo, la creación debe fallar con CacheError."""
    fake_base = tmp_path / "not_a_dir"
    fake_base.write_text("soy un archivo")
    with pytest.raises(CacheError):
        _ = Cache(app_name="x", base_dir=fake_base)


def test_set_exists_load_and_delete(tmp_path: Path):
    """Prueba guardar, leer, calcular edad y borrar correctamente un archivo en caché."""
    c = Cache(app_name="x", base_dir=tmp_path)
    c.set("hola.txt", "hola mundo")
    assert c.exists("hola.txt")
    assert c.load("hola.txt") == "hola mundo"

    age_ms = c.how_old("hola.txt")
    assert isinstance(age_ms, float) and age_ms >= 0.0

    c.delete("hola.txt")
    assert not c.exists("hola.txt")
    c.delete("hola.txt")  # idempotente


def test_exists_invalid_name_returns_false(tmp_path: Path):
    """Nombres inválidos no deben causar excepción; deben devolver False."""
    c = Cache(app_name="x", base_dir=tmp_path)
    assert c.exists("a/b") is False
    assert c.exists("a\\b") is False
    assert c.exists("") is False


def test_set_fails_if_target_is_directory(tmp_path: Path):
    """Si existe un directorio con el mismo nombre, set() debe fallar."""
    c = Cache(app_name="x", base_dir=tmp_path)
    (Path(c.cache_dir) / "como_fichero.txt").mkdir()
    with pytest.raises(CacheError):
        c.set("como_fichero.txt", "contenido")


def test_load_missing_raises(tmp_path: Path):
    """Cargar un archivo inexistente debe lanzar CacheError."""
    c = Cache(app_name="x", base_dir=tmp_path)
    with pytest.raises(CacheError):
        c.load("no_existe.txt")


def test_load_fails_if_target_is_directory(tmp_path: Path):
    """Si el objetivo es un directorio, load() debe lanzar CacheError."""
    c = Cache(app_name="x", base_dir=tmp_path)
    (Path(c.cache_dir) / "es_directorio.txt").mkdir()
    with pytest.raises(CacheError):
        c.load("es_directorio.txt")


def test_how_old_missing_raises(tmp_path: Path):
    """Si el archivo no existe, how_old() debe lanzar CacheError."""
    c = Cache(app_name="x", base_dir=tmp_path)
    with pytest.raises(CacheError):
        c.how_old("no_existe.txt")


@pytest.mark.skipif(sys.platform != "win32", reason="Solo aplica en Windows por bloqueo de archivos.")
def test_clear_raises_if_a_file_is_locked_on_windows(tmp_path: Path):
    """En Windows, si un archivo está abierto y bloqueado, clear() debe lanzar CacheError."""
    c = Cache(app_name="x", base_dir=tmp_path)
    f1 = Path(c.cache_dir) / "bloqueado.txt"
    f2 = Path(c.cache_dir) / "libre.txt"
    f1.write_text("A", encoding="utf-8")
    f2.write_text("B", encoding="utf-8")

    fh = open(f1, "r+", encoding="utf-8")
    try:
        with pytest.raises(CacheError):
            c.clear()
        assert f1.exists()
    finally:
        fh.close()
        if f1.exists():
            f1.unlink()
        assert Path(c.cache_dir).exists()


def test_clear_removes_files_but_keeps_subdirs(tmp_path: Path):
    """clear() borra archivos pero mantiene subcarpetas."""
    c = Cache(app_name="x", base_dir=tmp_path)
    f1 = Path(c.cache_dir) / "f1.txt"
    f2 = Path(c.cache_dir) / "f2.txt"
    subdir = Path(c.cache_dir) / "subdir"
    f1.write_text("1", encoding="utf-8")
    f2.write_text("2", encoding="utf-8")
    subdir.mkdir()

    c.clear()
    assert not f1.exists()
    assert not f2.exists()
    assert subdir.exists() and subdir.is_dir()


def test_delete_raises_if_target_is_directory(tmp_path: Path):
    """delete() debe lanzar CacheError si el objetivo es un directorio."""
    c = Cache(app_name="x", base_dir=tmp_path)
    (Path(c.cache_dir) / "no_es_archivo.txt").mkdir()
    with pytest.raises(CacheError):
        c.delete("no_es_archivo.txt")


############################
# Tests para CacheURL
############################

def test_cacheurl_get_and_cache_with_ttl(tmp_path: Path, requests_mock):
    """Primera descarga desde red; la segunda usa caché (TTL vigente)."""
    c = CacheURL(app_name="tests_cacheurl", obsolescence=999, base_dir=tmp_path)
    url = "https://agenciatributaria.madrid.es/portal/site/contribuyente"

    requests_mock.get(url, text="A")
    t1 = c.get(url, timeout=5)
    assert t1 == "A"

    requests_mock.get(url, text="B")
    t2 = c.get(url, timeout=5)
    assert t2 == "A"

    assert any(Path(c.cache_dir).glob("*"))


def test_cacheurl_ttl_expired_triggers_refresh(tmp_path: Path, requests_mock):
    """Si el TTL expira, se refresca desde la red."""
    c = CacheURL(app_name="tests_cacheurl", obsolescence=0, base_dir=tmp_path)
    url = "https://agenciatributaria.madrid.es/portal/site/contribuyente"
    requests_mock.get(url, text="X")
    _ = c.get(url)

    c._obsolescence = -1
    requests_mock.get(url, text="Y")
    out = c.get(url)
    assert out == "Y"


def test_cacheurl_kwargs_affect_key(tmp_path: Path, requests_mock):
    """Cambiar kwargs produce claves de caché distintas."""
    c = CacheURL(app_name="tests_cacheurl", obsolescence=999, base_dir=tmp_path)
    url = "https://agenciatributaria.madrid.es/portal/site/contribuyente"

    requests_mock.get(url, text="Q=madrid")
    a = c.get(url, params={"q": "madrid"})
    requests_mock.get(url, text="Q=barcelona")
    b = c.get(url, params={"q": "barcelona"})
    assert a != b


def test_cacheurl_network_error_uses_fallback(tmp_path: Path, requests_mock):
    """Si la red falla pero hay caché, usa la copia local (fallback)."""
    c = CacheURL(app_name="tests_cacheurl", obsolescence=999, base_dir=tmp_path)
    url = "https://agenciatributaria.madrid.es/portal/site/contribuyente"

    requests_mock.get(url, text="OK")
    _ = c.get(url)

    requests_mock.get(url, status_code=500)
    out = c.get(url)
    assert out == "OK"


def test_cacheurl_delete_and_exists(tmp_path: Path, requests_mock):
    """Prueba delete() y exists() sobre CacheURL."""
    c = CacheURL(app_name="tests_cacheurl", obsolescence=999, base_dir=tmp_path)
    url = "https://agenciatributaria.madrid.es/portal/site/contribuyente"
    requests_mock.get(url, text="Z")
    _ = c.get(url)

    assert c.exists(url)
    age = c.how_old(url)
    assert age >= 0
    c.delete(url)
    assert not c.exists(url)


def test_cacheurl_ttl_expired_refresh(tmp_path, requests_mock):
    """Verifica que el TTL expirado provoca refresco de datos."""
    cu = CacheURL(app_name="ttl", obsolescence=0, base_dir=tmp_path)
    url = "https://example.com/a"
    requests_mock.get(url, text="V1")
    _ = cu.get(url)
    cu._obsolescence = -1
    requests_mock.get(url, text="V2")
    assert cu.get(url) == "V2"


def test_cacheurl_kwargs_change_key(tmp_path, requests_mock):
    """Confirma que distintos kwargs generan claves diferentes."""
    cu = CacheURL(app_name="k", obsolescence=999, base_dir=tmp_path)
    url = "https://example.com/search"
    requests_mock.get(url, text="madrid")
    a = cu.get(url, params={"q": "madrid"})
    requests_mock.get(url, text="barcelona")
    b = cu.get(url, params={"q": "barcelona"})
    assert a != b


def test_cacheurl_network_error_without_cache_raises(tmp_path, requests_mock):
    """Si la red falla y no hay caché previa, debe lanzar CacheError."""
    cu = CacheURL(app_name="err", obsolescence=999, base_dir=tmp_path)
    url = "https://example.com/bad"
    requests_mock.get(url, status_code=500)
    with pytest.raises(CacheError):
        cu.get(url)


def test_cacheurl_network_error_and_bad_cached_entry_raises(tmp_path, requests_mock):
    """Si hay un archivo corrupto (directorio) y la red falla, lanza CacheError."""
    cu = CacheURL(app_name="errbad", obsolescence=999, base_dir=tmp_path)
    url = "https://example.com/cached-bad"
    key = cu._key(url)
    bad_entry = Path(cu.cache_dir) / key
    bad_entry.mkdir(parents=True, exist_ok=True)
    requests_mock.get(url, status_code=500)
    with pytest.raises(CacheError):
        cu.get(url)


def test_cacheurl_kwargs_order_independent(tmp_path, requests_mock):
    """Los kwargs deben generar la misma clave aunque cambie el orden."""
    cu = CacheURL(app_name="kwargs_order", obsolescence=999, base_dir=tmp_path)
    url = "https://example.com/search"

    params_a = {"q": "madrid", "page": 2}
    params_b = {"page": 2, "q": "madrid"}

    requests_mock.get(url, text="RESULT")
    t1 = cu.get(url, params=params_a)

    requests_mock.get(url, text="OTHER")
    t2 = cu.get(url, params=params_b)

    assert t1 == t2 == "RESULT"
    assert cu._key(url, params=params_a) == cu._key(url, params=params_b)


def test_set_invalid_name_raises(tmp_path: Path):
    """set() con nombre inválido (rutas o vacío) debe lanzar CacheError."""
    c = Cache(app_name="x", base_dir=tmp_path)
    with pytest.raises(CacheError):
        c.set("sub/dir.txt", "contenido")
    with pytest.raises(CacheError):
        c.set("sub\\dir.txt", "contenido")
    with pytest.raises(CacheError):
        c.set("", "contenido")
