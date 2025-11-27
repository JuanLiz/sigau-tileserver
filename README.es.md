# sigau-tileserver

[English](./README.md) | Español

Pipeline para generar y servir **vector tiles (MBTiles)** del **Censo de Arbolado Urbano (SIGAU)** y **Localidades** de Bogotá.

👉 **Demo en vivo:** [https://tileserver.juanliz.com](https://tileserver.juanliz.com)

## Características

| Dataset | Descripción | Rango de zoom |
|---------|-------------|---------------|
| `sigau.mbtiles` | Puntos individuales de árboles | 12–18 |
| `sigau-clustered.mbtiles` | Datos de árboles agrupados | 8–15 |
| `localities.mbtiles` | Polígonos de localidades de Bogotá | 0–18 |

> [!IMPORTANT]  
> El tileserver expone las propiedades y atributos tal cual los proveen las fuentes originales. No se realizan modificaciones adicionales a las características de los datos; para detalles completos de atributos, esquemas y licencias, consulta las fuentes listadas en la sección "Fuentes de Datos".

## Inicio Rápido

Elige la opción que mejor se adapte a tus necesidades:

| Opción | Caso de uso | Requisitos |
|--------|-------------|------------|
| **A. Descargar la imagen** | La forma más rápida | Docker |
| **B. Construir Docker localmente** | Para personalizar la compilación | Docker |
| **C. Tiles pre-generados** | Servir los MBTiles incluidos directamente | Node.js o Tileserver-GL |
| **D. Generación manual** | Personalizar parámetros o usar datos actualizados | GDAL, Tippecanoe, Tileserver-GL |

## Opción A – Descargar la imagen

La forma más rápida de comenzar. Descarga la imagen pre-construida desde GitHub Container Registry:

```bash
docker pull ghcr.io/juanliz/sigau-tileserver:latest
docker run -p 8080:8080 ghcr.io/juanliz/sigau-tileserver:latest
```

Luego abre [http://localhost:8080](http://localhost:8080).

## Opción B – Construir Docker Localmente

El Dockerfile hará:

1. Descargar los datasets
2. Convertirlos a EPSG:4326
3. Generar MBTiles con Tippecanoe
4. Servirlos con Tileserver-GL

Construye la imagen tú mismo localmente:

```bash
docker build -t sigau-tileserver .
docker run -p 8080:8080 sigau-tileserver
```

Luego abre [http://localhost:8080](http://localhost:8080).

## Opción C – Servir Tiles Pre-generados

Si no necesitas regenerar los tiles, puedes servir los MBTiles incluidos directamente.

**Con npx (sin instalación requerida):**

```bash
npx tileserver-gl data/
```

**Con instalación global:**

```bash
tileserver-gl data/
```

Esta es una opción ligera si ya tienes los archivos MBTiles.

## Opción D – Generación Manual

Para control total del pipeline, sigue estos pasos:

### 1. Descargar archivos GeoJSON

- **Censo de Arbolado Urbano (SIGAU):**  
  [https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano](https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano)

- **Localidades de Bogotá (IDECA):**  
  [https://www.ideca.gov.co/recursos/mapas/localidad-bogota-dc](https://www.ideca.gov.co/sites/default/files/recursos/mapas/localidad_bogota_dc.geojson)

### 2. Convertir a EPSG:4326

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  arboladourbano_wgs84.geojson arboladourbano.geojson

ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  localities_wgs84.geojson localities_raw.geojson
```

### 3. Generar MBTiles con Tippecanoe

Aquí están los comandos para crear cada archivo MBTiles. Puedes ajustar los parámetros según tus necesidades.

**Puntos individuales de árboles (`sigau.mbtiles`):**

```bash
tippecanoe \
  -o sigau.mbtiles \
  -l arboladourbano \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --no-feature-limit \
  --no-tile-size-limit \
  --minimum-zoom=12 \
  --maximum-zoom=18 \
  --force \
  arboladourbano_wgs84.geojson
```

**Puntos de árboles agrupados (`sigau-clustered.mbtiles`):**

```bash
tippecanoe \
  -o sigau-clustered.mbtiles \
  --layer=clusters \
  --no-feature-limit \
  --no-tile-size-limit \
  --minimum-zoom=8 \
  --maximum-zoom=15 \
  --cluster-distance=40 \
  --cluster-maxzoom=15 \
  --cluster-densest-as-needed \
  arboladourbano_wgs84.geojson
```

**Polígonos de localidades (`localities.mbtiles`):**

```bash
tippecanoe \
  -o localities.mbtiles \
  --layer=localities \
  --no-feature-limit \
  --no-tile-size-limit \
  --minimum-zoom=0 \
  --maximum-zoom=18 \
  --coalesce-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --force \
  localities_wgs84.geojson
```

### 4. Servir con Tileserver-GL

Copia los archivos `.mbtiles` generados a tu directorio `data/` y ejecuta:

```bash
npx tileserver-gl data/
```

## Fuentes de Datos

| Dataset | Fuente | Licencia |
|---------|--------|----------|
| Localidades de Bogotá | [IDECA](https://www.ideca.gov.co/recursos/mapas/localidad-bogota-dc) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Censo de Arbolado Urbano | [Datos Abiertos Bogotá](https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

## ¿Por qué no usar el servicio REST de SIGAU directamente?

El servicio REST de SIGAU [https://sigau.ideca.gov.co/arcgis/rest/services/ArboladoUrbano/FeatureServer/0](https://sigau.ideca.gov.co/arcgis/rest/services/ArboladoUrbano/FeatureServer/0) funciona como una capa de entidades de ArcGIS (v. 10.81), no como un tileserver. Esto implica que los datos se obtienen mediante consultas puntuales al endpoint en lugar de solicitar tiles vectoriales pre-generados, lo que dificulta la entrega eficiente de grandes volúmenes de puntos.

Además, el servicio impone un límite de 2000 registros por petición, por lo que recuperar el conjunto completo requiere paginación o subdivisión espacial. Devuelve geometrías puntuales (WKID 4686) con un conjunto amplio de atributos, pero no ofrece mecanismos para el teselado espacial ni para el cacheado de tiles vectoriales.

Por tanto, cualquier aplicación que dependa directamente de este endpoint necesita implementar estrategias adicionales —particionado espacial, cachés locales y consultas optimizadas— para evitar tiempos de carga elevados y un número excesivo de peticiones. En la práctica, esto hace que el servicio no sea adecuado para la entrega en tiempo real de datos de alta densidad sin una capa intermedia de optimización.

## Licencia

- **Datasets:** Licenciados por IDECA y Datos Abiertos Bogotá bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).  
  Se requiere atribución al usar o redistribuir los datos.

- **Código:** Los scripts y configuración de este repositorio están licenciados bajo la [Licencia MIT](LICENSE).
