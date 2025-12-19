# Scala - Data Engineering - ETL

En este proyecto nos centramos en:

* Leer **múltiples ficheros CSV** desde un directorio,
* Cargar todo en memoria,
* Hacer una **agregación configurable**,
* Y **escribir** un CSV de salida,
* Con **configuración externa** mediante **Typesafe Config**.

Este ejercicio intenta reforzar conceptos clave de ingeniería de datos y buenas prácticas en Scala:

* **Encapsulación**: lectura, parsing, agregación y escritura separadas en clases/objetos específicos.
* **Configuración externa**: Typesafe Config para parámetros, sin recompilar.
* **Robustez**: múltiples formatos de fecha, manejo de líneas inválidas, patrón de ficheros.
* **Extensibilidad**: añadir más modos de agregación o nuevas claves de agrupación es trivial.

---

## Estructura del proyecto

```
oop-etl-example/
├─ build.sbt
├─ project/
│  ├─ plugins.sbt
│  └─ build.properties
├─ src
│  ├── main
│  │   ├── resources
│  │   │   └── reference.conf
│  │   └── scala
│  │       └── com
│  │           └── ntic
│  │               ├── config
│  │               │   ├── AppConfig.scala
│  │               │   └── ConfigLoader.scala
│  │               ├── domain
│  │               │   └── Transaction.scala
│  │               ├── io
│  │               │   ├── CsvParser.scala
│  │               │   ├── CsvWriter.scala
│  │               │   └── FileLister.scala
│  │               ├── Main.scala
│  │               └── service
│  │                   ├── AggMode.scala
│  │                   ├── Aggregator.scala
│  │                   └── GroupKey.scala
│  └── test
│      └── scala
└─ .gitignore
```

---

## `build.sbt`

### 1. Importaciones iniciales

```scala
import sbtassembly.AssemblyPlugin.autoImport._
import sbtassembly.{MergeStrategy, PathList}
```

Estas líneas importan funcionalidades del **plugin `sbt-assembly`**, que se usa para crear un único **JAR ejecutable** (también llamado *fat JAR* o *uber JAR*) con todas las dependencias incluidas.
Esto es útil, por ejemplo, cuando quieres desplegar tu aplicación en un entorno donde no hay `sbt`, sino solo un `java -jar`.

* `AssemblyPlugin.autoImport._` → habilita las claves de configuración como `assembly`, `assemblyMergeStrategy`, etc.
* `MergeStrategy` y `PathList` → sirven para definir cómo manejar conflictos al unir archivos de distintas dependencias (por ejemplo, varios `META-INF`).

---

### 2. Configuración global del proyecto

```scala
ThisBuild / organization := "com.ntic"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.13.17"
```

Estas tres líneas establecen la configuración **global** del *build*, es decir, se aplican a todos los subproyectos que pudieras tener (aunque en este caso solo hay uno).

* **organization** → el grupo o namespace del proyecto (como en Maven).
  Aquí: `com.ntic` → el paquete base.
* **version** → la versión del proyecto.
  `0.1.0-SNAPSHOT` indica que es una versión en desarrollo (*snapshot*).
* **scalaVersion** → versión del compilador Scala que se usará.
  En este caso, Scala **2.13.17**.

---

### 3. Definición del proyecto principal

```scala
lazy val root = (project in file("."))
  .settings(
    name := "bde_scala_2025_2026",
    assembly / mainClass := Some("com.ntic.Main"),
    assembly / assemblyJarName := s"${name.value}-${version.value}.jar",
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", xs @ _*) => MergeStrategy.discard
      case _ => MergeStrategy.first
    }
  )
```

#### Desglose:

* `lazy val root = (project in file("."))`
  Declara un proyecto `root` ubicado en el directorio actual (`.`).
  Es el proyecto principal de tu *build*.

* `.settings(...)`
  Define una lista de ajustes (*settings*) específicos de este proyecto.

Dentro de las `settings`:

| Clave                                                                 | Descripción                                                                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `name := "bde_scala_2025_2026"`                                       | Nombre del proyecto. Se usará, por ejemplo, para el nombre del JAR.                                                        |
| `assembly / mainClass := Some("com.ntic.Main")`                       | Clase principal que contiene el método `def main(args: Array[String]): Unit`. Es la que se ejecutará al hacer `java -jar`. |
| `assembly / assemblyJarName := s"${name.value}-${version.value}.jar"` | Nombre del archivo `.jar` generado, con el patrón `bde_scala_2025_2026-0.1.0-SNAPSHOT.jar`.                                |
| `assembly / assemblyMergeStrategy := { ... }`                         | Estrategia de *merge* (fusión) cuando varias dependencias incluyen archivos con el mismo nombre.                           |

---

#### Estrategia de merge

```scala
{
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case _ => MergeStrategy.first
}
```

Esto le indica a `sbt-assembly` cómo manejar conflictos entre archivos al combinar todas las dependencias en un solo JAR:

* Si el archivo está dentro de `META-INF/`, **descártalo** (`MergeStrategy.discard`), porque esos metadatos suelen causar conflictos.
* Para el resto de archivos, **quédate con el primero que encuentres** (`MergeStrategy.first`).

Así evitas errores típicos al construir el *fat JAR*.

---

### 4. Dependencias

```scala
libraryDependencies ++= Seq(
  "org.scalatest" %% "scalatest" % "3.2.19" % Test,
  "com.typesafe" % "config" % "1.4.5"
)
```

Lista de **dependencias** del proyecto, gestionadas por `sbt` (igual que Maven o Gradle).

| Dependencia                                        | Descripción                                                                                                                                                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `"org.scalatest" %% "scalatest" % "3.2.19" % Test` | Librería para escribir tests unitarios en Scala. El `%%` indica que sbt añadirá automáticamente el sufijo con la versión de Scala (`_2.13` en este caso). El `% Test` indica que solo se usará en el entorno de pruebas. |
| `"com.typesafe" % "config" % "1.4.5"`              | Librería para leer ficheros de configuración `.conf`, `.json`, o `.properties`. Muy común en proyectos Scala/Java. Aquí se usa `%` simple porque no depende de la versión de Scala.                                      |

---

# `project/build.properties`



---

# Configuración externa — `src/main/resources/reference.conf`

> Edita rutas y opciones aquí (¡sin recompilar!)

```hocon
app {
  input {
    dir = "data/in"          # Directorio con CSVs de entrada (ruta absoluta o relativa)
    pattern = ".*\\.csv"     # Regex para filtrar ficheros
    delimiter = ","          # Delimitador CSV (p.ej. ";" o ",")
    header = true            # Indica si los CSVs tienen cabecera
    // Columnas esperadas en cada CSV (en cualquier orden):
    // date, customerId, country, amount
  }

  transform {
    // Campo para agrupar: "country" o "customerId"
    groupBy = "country"
    // Modo de agregación: "sum", "avg", "count"
    aggregation = "sum"
    // Moneda / unidad opcional (sólo etiqueta en salida)
    unit = "EUR"
  }

  output {
    file = "data/out/aggregated.csv"  # Fichero de salida
    header = true
  }
}
```

---

# Dominio: Transaction — `src/main/scala/com/ntic/domain/Transaction.scala`

En los sistemas de procesamiento de datos, es común tener que modelar entidades del dominio que representen registros individuales de eventos o transacciones.

### Estructura a implementar

Implementa una clase de dominio denominada `Transaction` dentro del paquete `com.ntic.domain`.
Esta clase debe modelar una **transacción individual** registrada en un sistema de procesamiento de datos, representando un evento de compra o movimiento económico realizado por un cliente en una fecha determinada y asociado a un país.

La clase deberá ser definida como una **`case class` inmutable** que contenga exactamente los siguientes campos:

* `date`: fecha de la transacción (`LocalDate`)
* `customerId`: identificador único del cliente (`String`)
* `country`: país donde se realizó la transacción (`String`)
* `amount`: importe de la transacción (`BigDecimal`)

El uso de `case class` garantiza que la clase sea inmutable, facilite la comparación de instancias, la impresión legible de datos y la compatibilidad con las funciones de desestructuración y patrones (`pattern matching`) de Scala.

---

### Requisitos

1. **Paquete correcto:**
   La clase debe estar ubicada dentro del paquete `com.ntic.domain`.

2. **Definición de clase:**
   La clase debe declararse como `final case class` para evitar herencia y asegurar inmutabilidad.

3. **Tipos de datos adecuados:**

    * `date` debe ser de tipo `java.time.LocalDate` (no `String`).
    * `amount` debe ser de tipo `BigDecimal` para representar valores numéricos con precisión decimal.
    * `customerId` y `country` deben ser `String`.

4. **Inmutabilidad:**
   Todos los atributos deben ser inmutables (`val` implícitos en las `case class` de Scala).

5. **Representación semántica:**
   La clase debe representar una transacción única. Cada instancia equivale a un registro completo con todos sus campos informativos.

6. **Compatibilidad funcional:**
   La clase debe poder ser utilizada directamente en operaciones como `map`, `filter`, `groupBy`, y en construcciones de `pattern matching` dentro de colecciones Scala.

---

### Ejemplo de uso esperado

Supón que en el programa principal se leen transacciones desde un fichero CSV y se crean instancias de esta clase:

```scala
import com.ntic.domain.Transaction
import java.time.LocalDate

val t1 = Transaction(LocalDate.parse("2025-01-10"), "C001", "ES", BigDecimal(120.50))
val t2 = Transaction(LocalDate.parse("2025-01-11"), "C002", "FR", BigDecimal(80.00))
val t3 = Transaction(LocalDate.parse("2025-01-12"), "C001", "ES", BigDecimal(30.00))

val transactions = Seq(t1, t2, t3)
```

Estas instancias pueden utilizarse para realizar agregaciones, por ejemplo:

```scala
val totalPorPais = transactions.groupBy(_.country).map {
  case (pais, txs) => (pais, txs.map(_.amount).sum)
}
```

El resultado esperado sería un mapa como:

```
Map(ES -> 150.50, FR -> 80.00)
```

---

### ¿Por qué hacemos esto?

El objetivo de esta práctica es que los estudiantes comprendan cómo **modelar datos de dominio** de forma clara, tipada e inmutable.
Esta clase representa una **entidad fundamental** en sistemas ETL, analíticos o financieros, donde cada registro contiene información esencial para el procesamiento y la agregación de datos.

A través de esta implementación, se busca reforzar los siguientes conceptos:

* **Diseño orientado a datos:** representar una entidad real (transacción) mediante una estructura de datos pura.
* **Tipado fuerte:** utilizar tipos específicos (por ejemplo, `LocalDate` y `BigDecimal`) para prevenir errores de conversión o pérdida de precisión.
* **Inmutabilidad:** garantizar que los datos no cambien una vez creados, favoreciendo la seguridad y la programación funcional.
* **Facilidad de integración:** las `case class` se integran naturalmente con colecciones, JSON serializers, y librerías de lectura de ficheros.

En definitiva, esta clase servirá como bloque de construcción básico para el procesamiento posterior de datos en ejercicios de lectura, transformación y agregación.

---

### Verificar la implementación

Para validar la implementación, los estudiantes deben comprobar lo siguiente:

1. **Creación de instancias:**
   Pueden crear transacciones manualmente e imprimirlas:

   ```scala
   println(Transaction(LocalDate.now(), "C100", "DE", BigDecimal(99.99)))
   ```

   Debe mostrarse una representación legible y completa de la transacción.

2. **Inmutabilidad:**
   Intentar modificar un campo (por ejemplo, `t.amount = BigDecimal(0)`) debe producir un error de compilación.

3. **Desestructuración:**
   Verificar que se puede usar pattern matching:

   ```scala
   val Transaction(date, id, country, amount) = t1
   println(s"$id gastó $amount en $country el $date")
   ```

4. **Agrupaciones y transformaciones:**
   Confirmar que se puede usar en colecciones para sumar, filtrar o agrupar datos.

5. **Tipado fuerte:**
   Asegurarse de que la clase requiere tipos correctos (`LocalDate` y `BigDecimal`) y no acepta valores incompatibles como `String` o `Double` sin conversión explícita.

Una implementación correcta permitirá manipular fácilmente conjuntos de transacciones en posteriores ejercicios de lectura de ficheros CSV, agregación de datos y generación de informes.

---

# Config — `src/main/scala/com/ntic/config/AppConfig.scala`

En un proyecto de procesamiento de datos, es fundamental separar la **lógica de negocio** del **detalle de configuración**,
permitiendo que los parámetros del sistema (rutas, delimitadores, modos de agregación, etc.) se definan externamente, por ejemplo,
en un archivo `reference.conf` o `application.conf`.

Para poder cargar esta configuración de manera segura y estructurada, vamos a definir un conjunto de **clases inmutables** que r
epresenten la configuración de la aplicación. Estas clases serán posteriormente usadas por un cargador de configuración
(por ejemplo, con la librería *Typesafe Config*).

### Objetivo de la práctica

Debes implementar las **clases de configuración del sistema ETL**, garantizando:

1. Inmutabilidad: (usando `case class`).
2. Claridad semántica: cada campo debe representar exactamente un parámetro de configuración.
3. Tipado fuerte: todos los valores deben tener el tipo más adecuado (`String`, `Boolean`, etc.).
4. Escalabilidad: el diseño debe facilitar la extensión futura (añadir nuevos campos o secciones sin romper el código existente).

---

### Estructura a implementar

Dentro del paquete `com.ntic.config`, implementa las siguientes clases de tal manera que reflejen la configuración
descrita en el archivo `reference.conf` y que estas clases no se puedan modificar después de su creación:

- InputConfig: configuración de entrada (ubicación de ficheros, delimitador, etc.). Debe incluir:
    - `dir: String` - Directorio de entrada.
    - `pattern: String` - Expresión regular para filtrar ficheros.
    - `delimiter: String` - Delimitador CSV.
    - `header: Boolean` - Indica si los CSV tienen cabecera.
- TransformConfig: configuración de transformación (modo de agregación, campo de agrupación, etc.). Debe incluir:
    - `groupBy: String` - Campo para agrupar ("country" o "customerId").
    - `aggregation: String` - Modo de agregación ("sum", "avg", "count").
    - `unit: String` - Unidad de medida (p.ej. "EUR").
- OutputConfig: configuración de salida (fichero destino, si incluir cabecera, etc.). Debe incluir:
    - `file: String` - Fichero de salida.
    - `header: Boolean` - Indica si incluir cabecera en el fichero de salida.
- AppConfig: clase raíz que agrupa las tres secciones anteriores:
    - `input: InputConfig`
    - `transform: TransformConfig`
    - `output: OutputConfig`

### Requisitos

1. **Usa `final case class`**

    * `final` evita que la clase sea heredada.
    * `case class` proporciona automáticamente `equals`, `hashCode`, `toString`, y *copy*, favoreciendo la inmutabilidad y el uso en entornos funcionales.

2. **Ningún campo puede ser `var`.**
   Todas las propiedades deben ser **inmutables** (`val` implícito).

3. **Paquete correcto:**
   Todas las clases deben estar dentro del paquete `com.ntic.config`.

4. **Coherencia entre secciones:**
   La clase `AppConfig` debe agrupar exactamente tres secciones (`input`, `transform`, `output`) usando las clases anteriores.

---

### ¿Por qué hacemos esto?

* **Buena práctica de diseño:** separa la configuración del código ejecutable.
* **Seguridad y mantenibilidad:** evita errores de “string suelto” o configuraciones inconsistentes.
* **Facilidad de carga:** `Typesafe Config` (o cualquier otra librería similar) podrá mapear directamente los valores del archivo `reference.conf` a estas clases.
* **Tipado estático:** si una clave o tipo de configuración cambia, el compilador lo detectará.

---

# Loader de config — `src/main/scala/com/ntic/config/ConfigLoader.scala`

En los sistemas de procesamiento de datos profesionales, la configuración de la aplicación (rutas de ficheros, delimitadores, modos de agregación, formatos, etc.)
**no debe estar codificada directamente en el código fuente**, sino que se externaliza en ficheros de configuración.
En Scala, la librería **Typesafe Config** permite leer fácilmente estos parámetros desde un archivo `reference.conf` o `application.conf` y ponerlos a disposición del resto del programa.

En esta parte deberás implementar un **cargador de configuración** que lea el contenido del archivo `reference.conf` o `application.conf` y
construya un objeto `AppConfig` compuesto por las secciones de configuración `InputConfig`, `TransformConfig` y `OutputConfig`.

---

### Estructura a implementar

Implementar el objeto `ConfigLoader` dentro del paquete `com.ntic.config`, encargado de:

1. **Cargar el archivo de configuración** utilizando la clase `ConfigFactory` de la librería `com.typesafe.config`.
2. **Leer los valores de cada sección (`input`, `transform`, `output`)** a partir de sus rutas completas dentro del archivo `application.conf`.
3. **Construir instancias de las clases** `InputConfig`, `TransformConfig` y `OutputConfig` con los valores obtenidos.
4. **Agruparlas en una instancia de `AppConfig`** que será devuelta al resto del programa mediante un método `load()`.

---

### Requisitos

1. **Ubicación y firma del objeto**

    * Debe definirse dentro del paquete `com.ntic.config`.
    * Su definición debe ser `object ConfigLoader`.
    * Debe incluir un método público:

      ```scala
      def load(): AppConfig
      ```

2. **Lectura del archivo de configuración**

    * Debe usar `ConfigFactory.load()` para cargar el archivo `reference.conf` o `application.conf` desde el classpath.
    * Debe crear una instancia de `Config` que permita acceder a las claves usando `getString` o `getBoolean`, según el tipo de valor esperado.

3. **Estructura de configuración esperada**

    * La jerarquía del archivo de configuración será la siguiente:

      ```
      app {
        input { dir, pattern, delimiter, header }
        transform { groupBy, aggregation, unit }
        output { file, header }
      }
      ```
    * Cada una de estas secciones deberá mapearse correctamente a sus clases correspondientes:

        * `InputConfig`
        * `TransformConfig`
        * `OutputConfig`
        * Finalmente, `AppConfig` agrupará las tres.

4. **Correspondencia exacta entre claves y tipos**

    * Usa `getString` para valores textuales y `getBoolean` para los valores booleanos.
    * Debes respetar los nombres exactos de las claves (`"app.input.dir"`, `"app.transform.groupBy"`, etc.).

5. **Devolución de resultado**

    * El método `load()` debe devolver una instancia completamente construida de `AppConfig`.

---

### Ejemplo de uso esperado

El objetivo de esta clase es que otras partes del programa puedan obtener toda la configuración con una única llamada:

```scala
val config: AppConfig = ConfigLoader.load()
println(config.input.dir)
```

De este modo, el resto de la aplicación no necesita preocuparse de cómo ni desde dónde se cargan los parámetros de configuración.

---

### ¿Por qué hacemos esto?

* **Separación de responsabilidades:**
  `ConfigLoader` centraliza la lógica de carga y validación de la configuración, evitando duplicar código en otras partes del sistema.

* **Robustez y mantenibilidad:**
  Si en el futuro cambian las claves del archivo o se añaden nuevos parámetros, solo será necesario modificar este objeto.

* **Escalabilidad y buenas prácticas:**
  Este patrón es habitual en aplicaciones empresariales escritas en Scala, Akka o Spark, donde la configuración se carga al inicio del programa y se pasa como dependencia al resto de los módulos.

### Verificar la implementación

Pueden probarla con una pequeña *app*:

```scala
import example.config.ConfigLoader

object TestApp extends App {
  val conf = ConfigLoader.load()
  println(s"Directorio de entrada: ${conf.input.dir}")
  println(s"Agrupación: ${conf.transform.groupBy}")
  println(s"Fichero de salida: ${conf.output.file}")
}
```

---

# IO: Listar ficheros — `src/main/scala/com/ntic/io/FileLister.scala`

En muchos sistemas de procesamiento de datos, es común tener que **listar los ficheros contenidos en un directorio** para luego procesarlos.
Este listado suele necesitar **filtrar los ficheros según un patrón específico**, como una extensión determinada (por ejemplo, `.csv` o `.json`).

### Estructura a implementar

Implementa un objeto denominado `FileLister` dentro del paquete `com.ntic.io`. Este objeto deberá ofrecer un método público
llamado `listFiles`, cuya responsabilidad será **listar los ficheros de un directorio dado que cumplan un patrón determinado**
(expresado como una expresión regular).

La firma del método será la siguiente:

```scala
def listFiles(dir: String, regex: String): Seq[String]
```

El método debe:

1. Comprobar si el directorio indicado existe y es realmente un directorio; si no lo es, devolver una secuencia vacía.
2. Obtener la lista de todos los ficheros regulares (no subdirectorios) contenidos en dicho directorio.
3. Convertir las rutas obtenidas a cadenas de texto completas.
4. Filtrar únicamente aquellas rutas que coincidan con la expresión regular recibida como parámetro (`regex`).
5. Devolver la lista resultante en una secuencia (`Seq[String]`).

El objeto debe utilizar las clases `Files` y `Paths` del paquete `java.nio.file` y apoyarse en las conversiones de `scala.jdk.CollectionConverters._` para transformar los iteradores de Java a colecciones de Scala.

---

### Requisitos

1. **Paquete correcto:** la clase debe ubicarse en `com.ntic.io`.
2. **Tipo devuelto:** el método `listFiles` debe devolver una `Seq[String]` con las rutas absolutas de los ficheros encontrados.
3. **Validación de entrada:** si el directorio no existe o no es válido, el método debe devolver una secuencia vacía sin lanzar excepciones.
4. **Gestión de recursos:** el flujo (`stream`) abierto por `Files.list` debe cerrarse correctamente, incluso si ocurre una excepción; utiliza una construcción con `try`/`finally` para garantizarlo.
5. **Uso de expresiones regulares:** el filtrado de los ficheros debe realizarse mediante el método `matches` de `String` para comprobar que el nombre del fichero cumple el patrón especificado.
6. **Inmutabilidad:** no se deben usar estructuras mutables; el resultado final debe construirse de forma funcional, devolviendo una nueva secuencia.

---

### Ejemplo de uso esperado

Supón que en la carpeta `data/in` existen los siguientes archivos:

```
tx1.csv
tx2.csv
readme.txt
temp.csv.bak
```

El siguiente código:

```scala
import com.ntic.io.FileLister

val files = FileLister.listFiles("data/in", ".*\\.csv")
println(files)
```

debería producir una salida similar a:

```
List(data/in/tx1.csv, data/in/tx2.csv)
```

Si la carpeta indicada no existe, el método debe devolver:

```
List()
```

sin lanzar excepciones.

---

### ¿Por qué hacemos esto?

El objetivo de este ejercicio interactuar con el sistema de ficheros desde Scala utilizando la API `java.nio.file`.
Este ejercicio refuerza los siguientes conceptos:

* **Abstracción de acceso a datos:** separar la obtención de ficheros del resto de la lógica del programa.
* **Uso seguro de recursos:** asegurar el cierre de streams para evitar fugas de recursos.
* **Inmutabilidad y estilo funcional:** evitar el uso de variables mutables al construir colecciones.
* **Filtrado mediante expresiones regulares:** aprender a seleccionar dinámicamente ficheros que cumplan un patrón determinado.

Esta funcionalidad es fundamental en sistemas ETL y pipelines de datos, donde suele ser necesario procesar de forma dinámica todos los ficheros de un directorio según un patrón concreto (por ejemplo, `.*\\.csv` o `.*_2025\\.json`).

---

### Verificar la implementación

Para comprobar que la implementación funciona correctamente, se recomienda realizar las siguientes pruebas:

1. Crear un directorio de prueba con varios tipos de ficheros (por ejemplo, `.csv`, `.txt`, `.bak`).
2. Llamar a `FileLister.listFiles` con diferentes expresiones regulares:

    * `" .*\\.csv "` para obtener solo ficheros CSV.
    * `" .*\\.txt "` para obtener solo ficheros de texto.
    * `" .* "` para listar todos los ficheros.
3. Probar con un directorio inexistente para confirmar que el método devuelve una lista vacía sin errores.
4. Verificar que el flujo (`stream`) se cierra correctamente y no quedan recursos abiertos (el programa debe finalizar sin bloqueos).

El resultado correcto será una secuencia de rutas completas que coincidan con el patrón especificado, demostrando que el método cumple todos los requisitos funcionales y de estilo indicados.

---

# IO: parser CSV — `src/main/scala/com/ntic/io/CsvParser.scala`

En los sistemas de procesamiento de datos, es común tener que **leer y parsear ficheros CSV** para convertir sus líneas en objetos de dominio que puedan ser procesados posteriormente.

### Estructura a implementar

Implementa un objeto denominado `CsvParser` dentro del paquete `com.ntic.io`.
El objetivo de este objeto es **leer y procesar ficheros CSV**, convirtiendo sus líneas en instancias de la clase `Transaction` (ubicada en `com.ntic.domain.Transaction`).

El parser debe ser capaz de manejar diferentes formatos de fecha y permitir la lectura tanto de ficheros con cabecera como sin ella. Asimismo, debe ser tolerante a errores: las líneas inválidas no deben detener el proceso, sino descartarse silenciosamente.

El objeto debe ofrecer los siguientes elementos funcionales:

1. Una **lista privada de formatos de fecha admitidos**, usada para interpretar las fechas de los CSV.
2. Un **método privado `parseDate`** que pruebe sucesivamente los formatos de fecha hasta encontrar uno válido.
3. Un **método público `parseLine`** que reciba una línea CSV, un mapa con las posiciones de las columnas (`headerMap`) y el delimitador, y devuelva una instancia de `Transaction`.
4. Un **método público `readFile`** que lea un fichero completo, procese todas las líneas y devuelva una secuencia (`Seq[Transaction]`) con las transacciones válidas.

---

### Requisitos

1. **Paquete y nombre correctos**
   La clase debe ubicarse dentro del paquete `com.ntic.io` y llamarse exactamente `CsvParser`.

2. **Compatibilidad con distintos formatos de fecha**
   El método `parseDate` debe soportar al menos los siguientes formatos:

    * `YYYY-MM-DD` (ISO local)
    * `DD/MM/YYYY`
    * `YYYYMMDD`

   Si ninguna de las conversiones tiene éxito, debe lanzarse una `IllegalArgumentException` con un mensaje informativo.

3. **Estructura de las columnas**
   Los CSV contienen las columnas `date`, `customerId`, `country` y `amount`, en ese orden o con cabecera.

    * Si el parámetro `header` es `true`, el método debe leer la primera línea para construir un mapa de nombres de columna a posiciones.
    * Si `header` es `false`, debe asumir el orden fijo:

      ```
      date, customerId, country, amount
      ```

4. **Gestión de errores**

    * Las líneas vacías deben ser ignoradas.
    * Las líneas que provoquen excepciones durante el parseo deben descartarse sin interrumpir el proceso (usa `Try(...).toOption` para gestionarlo).

5. **Codificación y cierre de recursos**

    * La lectura debe realizarse con codificación UTF-8.
    * El objeto `Source` debe cerrarse siempre, incluso si ocurre un error (usa `try/finally`).

6. **Tipado correcto de campos**

    * `date`: `LocalDate`
    * `customerId`: `String`
    * `country`: `String`
    * `amount`: `BigDecimal`

7. **Devolución del resultado**
   El método `readFile` debe devolver una `Seq[Transaction]` con todas las transacciones válidas.

---

### Ejemplo de uso esperado

Supón que el fichero `data/in/transactions.csv` contiene lo siguiente:

```
date,customerId,country,amount
2025-01-10,C001,ES,120.50
20250111,C002,FR,80.00
11/01/2025,C003,PT,100.25
invalidDate,C004,ES,50.0
```

El siguiente código:

```scala
import com.ntic.io.CsvParser

val transactions = CsvParser.readFile("data/in/transactions.csv", ",", header = true)
transactions.foreach(println)
```

Debería producir una salida similar a:

```
Transaction(2025-01-10,C001,ES,120.50)
Transaction(2025-01-11,C002,FR,80.00)
Transaction(2025-01-11,C003,PT,100.25)
```

La línea con la fecha inválida (`invalidDate`) debe ser descartada sin generar un error en tiempo de ejecución.

---

### ¿Por qué hacemos esto?

Esta práctica tiene como propósito que los estudiantes adquieran competencias en:

* **Procesamiento de ficheros de texto estructurados (CSV)** desde Scala.
* **Uso de la API funcional** de Scala para tratar errores de forma segura con `Try` y `Option`, evitando que un error en una línea afecte al procesamiento completo.
* **Diseño de código limpio y modular**, separando la responsabilidad de parseo del resto de la lógica del sistema.
* **Manipulación robusta de fechas** en distintos formatos y validación de datos de entrada.
* **Buenas prácticas de manejo de recursos**, asegurando el cierre de ficheros abiertos.

Este tipo de parser es común en proyectos ETL o de ingeniería de datos, donde los sistemas deben ser tolerantes a errores
en los datos de origen sin detener el flujo completo de procesamiento.

---

### Verificar la implementación

Para comprobar que la implementación funciona correctamente, los estudiantes deben realizar las siguientes pruebas:

1. **CSV con cabecera válida:**
   Probar con un fichero que tenga los nombres de las columnas en la primera línea.
   Debe producir una secuencia de transacciones válidas.

2. **CSV sin cabecera:**
   Probar con un fichero donde el parámetro `header` se establezca en `false`.
   El parser debe leer los valores en el orden fijo definido.

3. **Fechas en distintos formatos:**
   Incluir líneas con fechas en los tres formatos admitidos y verificar que todas se interpretan correctamente.

4. **Líneas inválidas:**
   Incluir líneas con valores incorrectos o vacíos.
   Deben ser ignoradas sin lanzar excepciones.

5. **Gestión de recursos:**
   Confirmar que el fichero se cierra correctamente y que la aplicación no queda bloqueada tras su lectura.

6. **Comparación con valores esperados:**
   Verificar que el número total de transacciones devueltas coincide con el número de líneas válidas del CSV.

Una implementación correcta debe devolver un conjunto de transacciones coherente con los datos de entrada,
manejar adecuadamente las excepciones y cumplir las buenas prácticas de lectura y validación en Scala.


---

# IO: writer CSV — `src/main/scala/com/ntic/io/CsvWriter.scala`

En los sistemas de procesamiento de datos, habitual tener que **exportar resultados o informes en formato CSV** para su posterior análisis o consumo por otras aplicaciones.
Esto requiere escribir datos estructurados en disco, asegurando un formato correcto y una codificación adecuada.

### Estructura a implementar

Implementa un objeto denominado `CsvWriter` dentro del paquete `com.ntic.io`.
El propósito de este objeto es **escribir datos en formato CSV** en un fichero especificado por el usuario, permitiendo incluir opcionalmente una línea de cabecera.

El objeto deberá proporcionar un método público denominado `write`, con la siguiente firma:

```scala
def write(path: String, header: Option[String], rows: Seq[Seq[String]]): Unit
```

Este método deberá:

1. Crear el directorio de destino si no existe.
2. Convertir las filas (`rows`) en texto CSV, separando los campos de cada fila por comas.
3. Si se proporciona una cabecera (`Some(String)`), escribirla como primera línea; si no (`None`), omitirla.
4. Escribir todo el contenido en el fichero indicado, usando codificación UTF-8 y sobrescribiendo el contenido anterior si el fichero ya existe.

El resultado final debe ser un fichero de texto correctamente formateado en formato CSV.

---

### Requisitos

1. **Ubicación y nombre correcto:**
   El objeto debe estar ubicado en el paquete `com.ntic.io` y llamarse `CsvWriter`.

2. **Creación del directorio de salida:**
   Antes de escribir el fichero, el método debe comprobar si el directorio padre de la ruta existe; en caso contrario, crearlo con `Files.createDirectories`.

3. **Formato del contenido:**

    * Cada fila (`Seq[String]`) debe convertirse en una línea de texto separada por comas.
    * Todas las líneas deben unirse con el separador de línea del sistema (`System.lineSeparator()`).
    * Si hay cabecera (`Some`), debe colocarse como la primera línea del fichero.

4. **Codificación y escritura del fichero:**

    * Usar `StandardCharsets.UTF_8` como codificación.
    * Escribir el contenido con `Files.write`.
    * Utilizar las opciones `CREATE`, `TRUNCATE_EXISTING` y `WRITE` para crear o sobrescribir el fichero de salida.

5. **Tipado y estilo funcional:**

    * Utilizar `Option` para la cabecera, en lugar de condicionales nulos (`null`).
    * Mantener la inmutabilidad en todo el proceso (no usar variables mutables).

6. **No retorno:**
   El método no debe devolver ningún valor (tipo `Unit`); su única función es producir el fichero CSV en disco.

---

### Ejemplo de uso esperado

Supón que quieres exportar una lista de transacciones a un fichero CSV.

El siguiente código:

```scala
import com.ntic.io.CsvWriter

val header = Some("customerId,country,amount")
val rows = Seq(
  Seq("C001", "ES", "120.50"),
  Seq("C002", "FR", "80.00"),
  Seq("C003", "PT", "95.25")
)

CsvWriter.write("data/out/transactions.csv", header, rows)
```

Debe crear el fichero `data/out/transactions.csv` con el siguiente contenido:

```
customerId,country,amount
C001,ES,120.50
C002,FR,80.00
C003,PT,95.25
```

Si se llama al método con `None` como cabecera:

```scala
CsvWriter.write("data/out/noheader.csv", None, rows)
```

El fichero resultante no tendrá la primera línea de cabecera.

---

### ¿Por qué hacemos esto?

El propósito de esta práctica es que los estudiantes aprendan a **escribir datos estructurados en disco** aplicando buenas prácticas de ingeniería de software, reforzando varios conceptos clave:

1. **Separación de responsabilidades:**
   La escritura de datos se gestiona en una clase independiente, manteniendo el código limpio y modular.

2. **Gestión de ficheros en Scala:**
   Uso de la API moderna de `java.nio.file` para manipular rutas, crear directorios y escribir ficheros de forma segura.

3. **Uso de colecciones inmutables:**
   Transformar colecciones (`Seq[Seq[String]]`) en texto plano sin mutar datos.

4. **Tratamiento funcional de opciones:**
   Uso correcto de `Option` para representar la existencia o ausencia de cabecera, evitando el uso de `null`.

5. **Codificación y portabilidad:**
   Garantizar que el fichero generado sea compatible entre sistemas operativos (Windows, macOS, Linux) y legible con cualquier aplicación que soporte CSV.

En entornos reales de ingeniería de datos, esta funcionalidad es fundamental para exportar resultados de transformaciones o agregaciones a ficheros externos que otros sistemas o usuarios puedan consumir.

---

### Verificar la implementación

Para comprobar que la implementación es correcta, los estudiantes deben realizar las siguientes pruebas:

1. **Escritura con cabecera:**
   Llamar al método con un `Some("col1,col2,col3")` y verificar que la primera línea del fichero sea la cabecera.

2. **Escritura sin cabecera:**
   Pasar `None` como parámetro y confirmar que el fichero no contenga cabecera.

3. **Creación automática de directorio:**
   Especificar una ruta dentro de un directorio que no exista y comprobar que se crea automáticamente.

4. **Sobrescritura de ficheros:**
   Ejecutar dos veces el método sobre el mismo fichero y verificar que el contenido anterior se reemplaza completamente.

5. **Codificación UTF-8:**
   Incluir caracteres acentuados o especiales y confirmar que se guardan correctamente en el fichero.

6. **Verificación de formato:**
   Abrir el fichero en un editor o una hoja de cálculo y confirmar que los campos están separados por comas y alineados correctamente.

Una implementación correcta generará un fichero CSV bien formado, con gestión segura de directorios y codificación estándar, demostrando el dominio del estudiante en operaciones de escritura de datos y uso de la API de ficheros en Scala.


---
# ADT: Modo de agregación — `src/main/scala/com/ntic/service/AggMode.scala`

En los sistemas de procesamiento de datos, es común tener que **definir modos de agregación** para resumir o combinar conjuntos de datos.

### Estructura a implementar

Implementa un tipo algebraico denominado `AggMode` dentro del paquete `com.ntic.service`.
El objetivo de esta estructura es **representar de forma tipada los diferentes modos de agregación** que pueden aplicarse a un conjunto de datos en un proceso analítico o ETL.

El diseño debe estar basado en el uso de **jerarquías selladas** (`sealed trait`) y objetos de caso (`case object`), lo que permitirá modelar un conjunto cerrado de opciones:

* `Sum`: representa una agregación por suma.
* `Avg`: representa una agregación por promedio.
* `Count`: representa una agregación por conteo de elementos.

Además, el objeto de compañía (`object AggMode`) debe incluir un método de utilidad `fromString`, encargado de convertir una cadena de texto en su representación `AggMode` correspondiente, lanzando una excepción si el valor recibido no es válido.

---

### Requisitos

1. **Paquete y estructura correcta:**

    * La clase debe ubicarse en el paquete `com.ntic.service`.
    * Se debe definir un **trait sellado** (`sealed trait AggMode`) para limitar las implementaciones a este mismo archivo, garantizando un conjunto cerrado de modos de agregación.

2. **Definición de los modos de agregación:**

    * Implementar tres objetos de caso (`case object`) que extiendan `AggMode`:

        * `Sum` → representa la suma de valores.
        * `Avg` → representa el cálculo de la media aritmética.
        * `Count` → representa el conteo de registros o elementos.

3. **Conversión desde texto (`fromString`):**

    * El método `fromString(s: String): AggMode` debe recibir una cadena y devolver el modo correspondiente, ignorando mayúsculas y minúsculas (`s.toLowerCase`).
    * Si el texto no coincide con ninguno de los valores esperados, debe lanzar una `IllegalArgumentException` con un mensaje informativo, por ejemplo:

      ```
      Aggregation no soportada: <valor>
      ```

4. **Tipado y seguridad:**

    * No deben utilizarse enumeraciones tradicionales ni constantes de texto.
    * La correspondencia entre cadenas y modos debe ser estricta y controlada.

5. **Inmutabilidad y patrón funcional:**

    * La implementación debe ser completamente inmutable.
    * El uso de `sealed trait` y `case object` permite aplicar `pattern matching` de forma exhaustiva en otros componentes del sistema.

---

### Ejemplo de uso esperado

Supón que un módulo de agregación de datos necesita determinar el tipo de operación a realizar a partir de una configuración textual.
El siguiente código:

```scala
import com.ntic.service.AggMode

val mode1 = AggMode.fromString("sum")
val mode2 = AggMode.fromString("AVG")
val mode3 = AggMode.fromString("count")

println(mode1) // Sum
println(mode2) // Avg
println(mode3) // Count
```

Debe devolver las instancias correspondientes de `AggMode`.
En cambio, si se introduce un valor no reconocido:

```scala
AggMode.fromString("median")
```

El sistema debe lanzar la excepción:

```
java.lang.IllegalArgumentException: Aggregation no soportada: median
```

---

### ¿Por qué hacemos esto?

Este ejercicio tiene como objetivo que los estudiantes comprendan cómo **modelar opciones finitas de comportamiento** de forma segura y expresiva mediante **tipos algebraicos** en Scala.
En lugar de usar valores de texto o números mágicos, se define un tipo cerrado (`sealed trait`) con alternativas explícitas, lo que ofrece varias ventajas:

* **Seguridad en tiempo de compilación:** el compilador puede detectar usos incorrectos o no cubiertos en un `match`.
* **Legibilidad y expresividad:** el código que maneja agregaciones se vuelve autoexplicativo (`AggMode.Sum` es más claro que `"sum"`).
* **Evita errores de configuración:** los valores no reconocidos se detectan tempranamente al lanzar una excepción controlada.
* **Estilo funcional:** fomenta el uso de estructuras inmutables y exhaustivas, alineadas con la filosofía de Scala y la programación segura.

Este patrón es ampliamente utilizado en sistemas de ingeniería de datos, por ejemplo, para representar operaciones de agregación, estados de ejecución, o modos de procesamiento (p. ej., `Batch`, `Stream`, `Incremental`).

---

### Verificar la implementación

Para comprobar que la implementación es correcta, los estudiantes deben realizar las siguientes pruebas:

1. **Conversión válida:**

    * Llamar a `AggMode.fromString("sum")`, `AggMode.fromString("avg")` y `AggMode.fromString("count")` y verificar que devuelven los objetos correctos.
    * Repetir las pruebas con combinaciones en mayúsculas y minúsculas (`"SUM"`, `"Avg"`, `"Count"`).

2. **Conversión inválida:**

    * Probar con una cadena no reconocida, por ejemplo `"total"`, y confirmar que lanza una `IllegalArgumentException` con el mensaje adecuado.

3. **Exhaustividad del patrón:**

    * Implementar un `match` sobre un valor de tipo `AggMode` y verificar que el compilador exige cubrir los tres casos (`Sum`, `Avg`, `Count`).

4. **Inmutabilidad y unicidad:**

    * Confirmar que `AggMode.Sum eq AggMode.Sum` devuelve `true`, indicando que cada modo es un único objeto compartido, no una nueva instancia.

Una implementación correcta producirá un tipo seguro, expresivo y extensible que podrá utilizarse directamente en ejercicios posteriores de agregación de datos o transformación de colecciones.

---

# ADT: Llave de agroupación — `src/main/scala/com/ntic/service/GroupKey.scala`

Este ADT es similar al anterior, pero para representar las claves por las que se puede agrupar.

### Estructura a implementar

Debes implementar una clase y su objeto de compañía en el paquete `com.ntic.service`, con el nombre **`GroupKey`**, que represente un conjunto limitado de claves posibles para agrupar datos dentro de un sistema de procesamiento (por ejemplo, un job de agregación o un servicio de reporting).

La estructura debe seguir el patrón de una **jerarquía sellada (sealed trait)** que defina el tipo base `GroupKey`, y dos **implementaciones concretas** en forma de objetos (`case object`):

* `Country`
* `CustomerId`

Además, se requiere definir un **método factoría** (`fromString`) dentro del objeto acompañante que reciba un `String` y devuelva la instancia de `GroupKey` correspondiente, lanzando una excepción si el valor no está soportado.

---

### Requisitos

1. La clase base debe declararse como un **`sealed trait`** para restringir la herencia a este archivo, garantizando la exhaustividad del patrón `match`.
2. Las implementaciones deben ser **`case object`** y estar definidas dentro del `object GroupKey`.
3. El método `fromString(s: String): GroupKey` debe:

    * Aceptar valores de texto con cualquier combinación de mayúsculas/minúsculas.
    * Retornar `Country` si el texto es `"country"`.
    * Retornar `CustomerId` si el texto es `"customerid"`.
    * Lanzar una excepción `IllegalArgumentException` con un mensaje descriptivo si el valor no es reconocido.
4. La clase debe estar correctamente **empaquetada** bajo `package com.ntic.service`.

---

### Ejemplo de uso esperado

```scala
import com.ntic.service.GroupKey

val key1 = GroupKey.fromString("country")     // Devuelve GroupKey.Country
val key2 = GroupKey.fromString("CUSTOMERID")  // Devuelve GroupKey.CustomerId
val key3 = GroupKey.fromString("region")      // Lanza IllegalArgumentException
```

---

### ¿Por qué hacemos esto?

Este ejercicio tiene como objetivo que el estudiante:

* Comprenda el uso de **traits sellados** para modelar jerarquías cerradas y garantizar el control en la definición de tipos.
* Practique el uso de **case objects** como instancias únicas e inmutables.
* Implemente una **factoría controlada** (`fromString`) para convertir representaciones textuales en valores de dominio, algo común en entornos de procesamiento de datos donde las claves suelen recibirse como texto (por ejemplo, en configuraciones o parámetros de API).
* Aplique buenas prácticas de **manejo de errores** mediante excepciones descriptivas.

---

### Verificar la implementación

Para verificar tu código, asegúrate de que se cumpla lo siguiente:

1. **Compilación correcta**:
   El archivo debe compilar sin errores y pertenecer al paquete `com.ntic.service`.

2. **Comprobaciones de comportamiento**:

    * `GroupKey.fromString("country") == GroupKey.Country`
    * `GroupKey.fromString("CustomerId") == GroupKey.CustomerId`
    * `GroupKey.fromString("invalid")` lanza `IllegalArgumentException`.

3. **Cobertura del patrón match**:
   En cualquier `match` sobre `GroupKey`, el compilador no debe emitir advertencias de patrones no exhaustivos.

4. **Buena práctica de diseño**:
   La implementación debe evitar el uso de enumeraciones o `if` anidados, utilizando `match` como estructura principal.


---

# Servicio de agregación — `src/main/scala/com/ntic/service/Aggregator.scala`

En los sistemas de procesamiento de datos, se suele **agrupar y calcular métricas** sobre conjuntos de transacciones o eventos, basándose en claves específicas y modos de agregación definidos.
Esta lógica es fundamental en tareas de análisis, reporting y generación de insights a partir de datos brutos. Además, es una lógica de negocio común en sistemas ETL y pipelines de datos.

### Estructura a implementar

Debes implementar un objeto llamado **`Aggregator`** dentro del paquete `com.ntic.service`. Este objeto representará una utilidad encargada de **agrupar y calcular métricas** sobre un conjunto de transacciones (`Transaction`) en función de una clave y un modo de agregación determinados.

La función principal del objeto será **`aggregate`**, que deberá:

1. Agrupar los datos según una clave (`GroupKey`).
2. Calcular una métrica sobre cada grupo en función de un modo (`AggMode`).
3. Devolver los resultados ordenados de forma descendente por el valor de la métrica.

La estructura general del método debe ser:

```scala
def aggregate(
  data: Seq[Transaction],
  groupBy: GroupKey,
  mode: AggMode
): Seq[(String, BigDecimal)]
```

---

### Requisitos

1. **Paquete y dependencias**

    * El objeto debe ubicarse en el paquete `com.ntic.service`.
    * Debe importar la clase `Transaction` desde `com.ntic.domain.Transaction`.
    * Utilizar los tipos `GroupKey` y `AggMode`, definidos en otros módulos del proyecto.

2. **Entrada del método**

    * `data`: una secuencia de objetos `Transaction`, cada uno con al menos los campos `country: String`, `customerId: String` y `amount: BigDecimal`.
    * `groupBy`: una instancia de `GroupKey` que determina si se agrupa por país (`Country`) o por cliente (`CustomerId`).
    * `mode`: una instancia de `AggMode` que define el tipo de métrica a calcular:

        * `Sum`: suma de los importes (`amount`).
        * `Count`: número de transacciones.
        * `Avg`: media de los importes.

3. **Salida esperada**

    * Una secuencia de tuplas `(String, BigDecimal)` donde:

        * El primer elemento es la clave del grupo (país o cliente).
        * El segundo es la métrica calculada.
    * El resultado debe estar **ordenado de forma descendente** según la métrica.

4. **Comportamiento adicional**

    * Si el grupo no contiene transacciones y el modo es `Avg`, debe devolver `0`.
    * Utiliza `groupBy` y `map` funcionales de Scala, **no bucles imperativos**.
    * Se debe garantizar la inmutabilidad de las estructuras de datos.

---

### Ejemplo de uso esperado

```scala
import com.ntic.service.{Aggregator, GroupKey}
import com.ntic.domain.Transaction
import com.ntic.service.AggMode

val data = Seq(
  Transaction("ES", "C001", BigDecimal(100)),
  Transaction("ES", "C002", BigDecimal(50)),
  Transaction("FR", "C001", BigDecimal(200)),
  Transaction("FR", "C003", BigDecimal(300))
)

// Agrupar por país y sumar importes
val result1 = Aggregator.aggregate(data, GroupKey.Country, AggMode.Sum)
// Ejemplo de salida: Seq(("FR", 500), ("ES", 150))

// Agrupar por cliente y contar transacciones
val result2 = Aggregator.aggregate(data, GroupKey.CustomerId, AggMode.Count)
// Ejemplo de salida: Seq(("C001", 2), ("C003", 1), ("C002", 1))
```

---

### ¿Por qué hacemos esto?

Este ejercicio tiene como objetivo que el estudiante:

* Practique la **programación funcional en Scala**, aplicando transformaciones inmutables sobre colecciones (`groupBy`, `map`, `foldLeft`, `sortBy`).
* Comprenda cómo diseñar **funciones puras** que encapsulan lógica de negocio sin efectos secundarios.
* Aprenda a **combinar tipos algebraicos (ADTs)** (`GroupKey`, `AggMode`) con estructuras de datos reales (`Transaction`) para construir soluciones limpias y extensibles.
* Desarrolle destrezas en la **composición funcional** para procesar datos de forma declarativa, una habilidad clave en entornos de *data engineering* y *stream processing* (p. ej., Spark o Flink).

---

### Verificar la implementación

Antes de dar por finalizado el ejercicio, asegúrate de que tu implementación cumple los siguientes criterios:

1. **Compilación correcta**

    * El archivo se encuentra en `src/main/scala/com/ntic/service/Aggregator.scala`.
    * No hay errores de compilación ni advertencias de coincidencias no exhaustivas.

2. **Resultados esperados**

    * Los resultados están correctamente ordenados en orden descendente por la métrica.
    * Se devuelven los tipos correctos: `Seq[(String, BigDecimal)]`.
    * El cálculo de `Sum`, `Count` y `Avg` es coherente con la entrada.

3. **Robustez del código**

    * No hay mutaciones ni variables `var`.
    * No se utilizan `try/catch` para controlar la lógica esperada.
    * La función `aggregate` se comporta igual ante múltiples invocaciones con los mismos datos (inmutabilidad y pureza).

4. **Comprobación adicional (tests sugeridos)**

    * Conjunto vacío de transacciones → devuelve `Seq.empty`.
    * Agrupación por `Country` con varios países.
    * Agrupación por `CustomerId` con repetición de clientes.
    * Validar el cálculo medio (`Avg`) en casos con una sola transacción y con varias.

---

# Punto de entrada — `src/main/scala/example/Main.scala`

```scala
package example

import example.config.{ConfigLoader}
import example.io.{FileLister, CsvParser, CsvWriter}
import example.service.Aggregator
import example.service.Aggregator.{AggMode, GroupKey}

object Main {
  def main(args: Array[String]): Unit = {
    val conf = ConfigLoader.load()

    println(s"[INFO] Leyendo ficheros de: ${conf.input.dir}")
    val files = FileLister.listFiles(conf.input.dir, conf.input.pattern)
    if (files.isEmpty) {
      println(s"[WARN] No se encontraron ficheros en ${conf.input.dir} con patrón ${conf.input.pattern}")
      sys.exit(0)
    }

    val allTx = files.flatMap { f =>
      val txs = CsvParser.readFile(f, conf.input.delimiter, conf.input.header)
      println(s"[INFO] ${f}: ${txs.size} transacciones válidas")
      txs
    }

    println(s"[INFO] Total transacciones: ${allTx.size}")

    val groupKey = GroupKey.fromString(conf.transform.groupBy)
    val aggMode  = AggMode.fromString(conf.transform.aggregation)

    val aggregated = Aggregator.aggregate(allTx, groupKey, aggMode)

    val headerOpt =
      if (conf.output.header) Some(s"${conf.transform.groupBy},${conf.transform.aggregation}(${conf.transform.unit})")
      else None

    val rows: Seq[Seq[String]] =
      aggregated.map { case (k, metric) => Seq(k, metric.bigDecimal.toPlainString) }

    CsvWriter.write(conf.output.file, headerOpt, rows)

    println(s"[INFO] Escrito: ${conf.output.file}")
  }
}
```

---

# Datos de ejemplo (crea tú mismo)

Crea un directorio `data/in/` con varios CSV del tipo:

**`data/in/tx1.csv`**

```csv
date,customerId,country,amount
2025-01-10,C001,ES,120.50
2025-01-11,C002,FR,80.00
10/01/2025,C001,ES,30.00
```

**`data/in/tx2.csv`**

```csv
date,customerId,country,amount
2025-01-12,C003,ES,50
20250113,C002,FR,25.5
2025-01-13,C004,PT,40.0
```

---

# ▶️ Cómo ejecutarlo

```bash
sbt compile
sbt run
```

* Ajusta `app.input.dir` y `app.output.file` en `application.conf`.
* Cambia `groupBy` a `"customerId"` o `"country"`.
* Cambia `aggregation` a `"sum"`, `"avg"` o `"count"`.

 