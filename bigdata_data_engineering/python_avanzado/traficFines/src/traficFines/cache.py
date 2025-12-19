from __future__ import annotations
from pathlib import Path
from typing import Optional
import datetime as dt
import hashlib
import json
import requests

class CacheError(Exception):
    """Errores del módulo `caché`."""
    pass


class Cache:
    """
    Caché de ficheros en disco.

    - Guarda y recupera texto (UTF-8) por un nombre (`name`).
    - Crea una carpeta por aplicación: ~/.my_cache/<app_name> (por defecto).
    - Permite saber la “edad” de un fichero en milisegundos para decidir si está “viejo”.
    """

    # Carpeta base por defecto para todas las apps
    DEFAULT_CACHE_DIR = Path.home() / ".my_cache"

    def __init__(
        self,
        app_name: str = "traficFines",
        obsolescence: int = 7,
        base_dir: Optional[Path | str] = None,
    ) -> None:
        """
        app_name: nombre de la app (se usa como subcarpeta).
        obsolescence: días que consideramos que la caché sigue siendo válida.
        base_dir: carpeta base donde crear la caché; si no se pasa, usa ~/.my_cache
        """
        try:
            self._app_name = str(app_name)
            self._obsolescence = int(obsolescence)

            base = Path(base_dir) if base_dir is not None else self.DEFAULT_CACHE_DIR
            self._cache_dir_path = Path(base).expanduser().resolve() / self._app_name
            self._cache_dir_path.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            raise CacheError(f"No se pudo inicializar la caché en {base_dir!r}") from e

    ############### Propiedades de solo lectura ###############
    @property
    def app_name(self) -> str:
        """Nombre de la aplicación asociado a esta caché."""
        return self._app_name

    @property
    def cache_dir(self) -> str:
        """Ruta absoluta (str) de la carpeta de caché de esta app."""
        return str(self._cache_dir_path)

    @property
    def obsolescence(self) -> int:
        """Obsolescencia (en días) configurada para esta caché."""
        return self._obsolescence

    ############### Utilidad interna ###############
    def _path(self, name: str) -> Path:
        """Ruta absoluta donde se guarda `name` dentro de la caché."""
        if not name or "/" in name or "\\" in name:
            # Evitamos rutas con subdirectorios o nombres raros
            raise CacheError(f"Nombre de entrada inválido: {name!r}")
        return self._cache_dir_path / name

    ############### API pública ###############
    def set(self, name: str, data: str) -> None:
        """
        Guarda `data` (texto UTF-8) con el identificador `name`.
        """
        p = self._path(name)
        try:
            p.write_text(data, encoding="utf-8")
        except Exception as e:
            raise CacheError(f"No se pudo guardar {name!r} en caché") from e

    def exists(self, name: str) -> bool:
        try:
            return self._path(name).exists()
        except CacheError:
            return False

    def load(self, name: str) -> str:
        """
        Devuelve el contenido (texto) asociado a `name`.
        Lanza CacheError si no existe.
        """
        p = self._path(name)
        if not p.exists():
            raise CacheError(f"No existe en caché: {name!r}")
        try:
            return p.read_text(encoding="utf-8")
        except Exception as e:
            raise CacheError(f"No se pudo leer {name!r} desde la caché") from e

    def how_old(self, name: str) -> float:
        """
        Devuelve la edad del fichero `name` en **milisegundos**.
        Lanza CacheError si no existe o si no es un fichero regular.
        """
        p = self._path(name)
        if not p.exists():
            raise CacheError(f"No existe en caché: {name!r}")
        if not p.is_file():
            # Es un directorio (u otro tipo); no tiene sentido calcular antigüedad como fichero
            raise CacheError(f"El objetivo no es un fichero regular: {name!r}")
        try:
            mtime = dt.datetime.fromtimestamp(p.stat().st_mtime)
            return (dt.datetime.now() - mtime).total_seconds() * 1000.0
        except Exception as e:
            raise CacheError(f"No se pudo calcular la edad de {name!r}") from e

    def delete(self, name: str) -> None:
        """
        Borra la entrada `name` si existe (si no, no pasa nada).
        """
        p = self._path(name)
        try:
            if p.exists():
                p.unlink(missing_ok=True)
        except Exception as e:
            raise CacheError(f"No se pudo borrar {name!r} de la caché") from e

    def clear(self) -> None:
        """
        Borra **todos** los ficheros de la caché de esta aplicación.
        """
        try:
            for f in self._cache_dir_path.glob("*"):
                if f.is_file():
                    f.unlink(missing_ok=True)
            # Si algún día creas subcarpetas, aquí podrías usar shutil.rmtree(f)
        except Exception as e:
            raise CacheError(f"No se pudo limpiar la caché en {self.cache_dir}") from e




class CacheURL(Cache):
    """
    Especialización de Cache para URLs:
    - Genera un nombre de fichero seguro a partir de un hash de (url + kwargs).
    - Si la caché está “vigente” (no obsoleta), devuelve el contenido cacheado.
    - Si no, hace la petición HTTP GET, guarda el resultado y lo devuelve.
    """

    def _key(self, url: str, **kwargs) -> str:
        """
        Genera un nombre de fichero estable y portable (hash md5)
        a partir de la URL y sus parámetros opcionales.
        """
        # Normalizamos kwargs para que el hash sea determinista
        def jsonable(x):
            try:
                json.dumps(x)
                return x
            except TypeError:
                return str(x)

        payload = {k: jsonable(kwargs[k]) for k in sorted(kwargs)}
        raw = json.dumps([url, payload], ensure_ascii=False, sort_keys=True)
        # Usamos md5 como en el ejemplo del enunciado
        return hashlib.md5(raw.encode("utf-8")).hexdigest() + ".txt"

    # Se sobreescribe los métodos de Cache para aceptar url+kwargs (en vez de name)
    def exists(self, url: str, **kwargs) -> bool:
        name = self._key(url, **kwargs)
        return super().exists(name)

    def load(self, url: str, **kwargs) -> str:
        name = self._key(url, **kwargs)
        return super().load(name)

    def how_old(self, url: str, **kwargs) -> float:
        """
        Edad en milisegundos del contenido cacheado para (url, kwargs).
        """
        name = self._key(url, **kwargs)
        return super().how_old(name)

    def delete(self, url: str, **kwargs) -> None:
        name = self._key(url, **kwargs)
        return super().delete(name)

    def get(self, url: str, **kwargs) -> str:
        """
        Devuelve el texto de `url`, usando la caché si no está obsoleta.
        Si no hay caché o está caducada, hace requests.get(url, **kwargs),
        guarda y devuelve el resultado.

        Reglas:
        - Vigencia: compara how_old(ms) con obsolescence (días → ms).
        - En errores de red: si hay algo en caché, lo devuelve como *fallback*.
          Si no hay nada, lanza CacheError.
        """
        name = self._key(url, **kwargs)

        # TTL: obsolescence (días) -> milisegundos
        ttl_ms = float(self.obsolescence) * 24 * 60 * 60 * 1000.0

        # Comprueba si hay caché y está dentro de plazo
        if super().exists(name):
            try:
                age_ms = super().how_old(name)
                if age_ms <= ttl_ms:
                    return super().load(name)
            except CacheError:
                pass

        # Descarga de red y guardado
        try:
            resp = requests.get(url, **kwargs)
            resp.raise_for_status()
            data = resp.text
            super().set(name, data)
            return data
        except Exception as e:
            if super().exists(name):
                try:
                    return super().load(name)
                except Exception:
                    pass
            raise CacheError(f"Error al obtener {url!r}: {e}") from e





























