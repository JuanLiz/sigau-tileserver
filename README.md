# sigau-tileserver

English | [Español](./README.es.md)

Pipeline for generating and serving **vector tiles (MBTiles)** of Bogotá's **Urban Tree Census (SIGAU)** and **Localities** datasets.

👉 **Live demo:** [https://tileserver.juanliz.com](https://tileserver.juanliz.com)

## Features

| Dataset | Description | Zoom range |
|---------|-------------|------------|
| `sigau.mbtiles` | Individual tree points | 12–18 |
| `sigau-clustered.mbtiles` | Pre-clustered tree data | 8–15 |
| `localities.mbtiles` | Bogotá locality polygons | 0–18 |

## Quick Start

Choose the option that best fits your needs:

| Option | Use case | Requirements |
|--------|----------|--------------|
| **A. Pull image** | Fastest way to run | Docker |
| **B. Build Docker locally** | For custom builds or development | Docker |
| **C. Pre-built tiles** | Serve the included MBTiles directly | Node.js or Tileserver-GL |
| **D. Manual generation** | Customize parameters or use fresh data | GDAL, Tippecanoe, Tileserver-GL |

## Option A – Pull image

The fastest way to get started. Pull the pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/juanliz/sigau-tileserver:latest
docker run -p 8080:8080 ghcr.io/juanliz/sigau-tileserver:latest
```

Then open [http://localhost:8080](http://localhost:8080).

## Option B – Build Docker Locally

The Dockerfile will:

1. Downloads the datasets
2. Converts them to EPSG:4326
3. Generates MBTiles via Tippecanoe
4. Serves them with Tileserver-GL

Build the image yourself locally.

```bash
docker build -t sigau-tileserver .
docker run -p 8080:8080 sigau-tileserver
```

Then open [http://localhost:8080](http://localhost:8080).

## Option C – Serve Pre-built Tiles

If you don't need to regenerate the tiles, you can serve the included MBTiles directly.

**With npx (no installation required):**

```bash
npx tileserver-gl data/
```

**With a global installation:**

```bash
tileserver-gl data/
```

This is a lightweight option if you already have the MBTiles files.

## Option D – Manual Generation

For full control over the pipeline, follow these steps:

### 1. Download GeoJSON files

- **Urban Tree Census (SIGAU):**  
  [https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano](https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano)

- **Bogotá Localities (IDECA):**  
  [https://www.ideca.gov.co/recursos/mapas/localidad-bogota-dc](https://www.ideca.gov.co/sites/default/files/recursos/mapas/localidad_bogota_dc.geojson)

### 2. Convert to EPSG:4326

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  arboladourbano_wgs84.geojson arboladourbano.geojson

ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  localities_wgs84.geojson localities_raw.geojson
```

### 3. Generate MBTiles with Tippecanoe

Here are the commands to create each MBTiles file. You can adjust parameters as needed.

**Individual tree points (`sigau.mbtiles`):**

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

**Clustered tree points (`sigau-clustered.mbtiles`):**

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

**Localities polygons (`localities.mbtiles`):**

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

### 4. Serve with Tileserver-GL

Copy the generated `.mbtiles` files to your `data/` directory and run:

```bash
npx tileserver-gl data/
```

## Data Sources

| Dataset | Source | License |
|---------|--------|---------|
| Bogotá Localities | [IDECA](https://www.ideca.gov.co/recursos/mapas/localidad-bogota-dc) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Urban Tree Census | [Datos Abiertos Bogotá](https://datosabiertos.bogota.gov.co/dataset/censo-arbolado-urbano) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

## Why not use the SIGAU REST service directly?

The REST service is provided by SIGAU at the following endpoint: [https://sigau.ideca.gov.co/arcgis/rest/services/ArboladoUrbano/FeatureServer/0](https://sigau.ideca.gov.co/arcgis/rest/services/ArboladoUrbano/FeatureServer/0). It operates as an ArcGIS Feature Layer (version 10.81) rather than a tileserver. This setup means that data must be retrieved through direct queries to the endpoint, which poses performance constraints given the large number of tree-point geometries for Bogotá. The service enforces a maximum record limit (2000 features per request), requiring either multiple paginated requests or spatial subdivisions to retrieve the full dataset. It returns point geometries (WKID 4686) with a broad attribute set, but lacks mechanisms for efficient spatial tiling or caching of vector tiles. As a result, any application relying on this service must implement complex strategies for spatial partitioning, local caching, and optimized querying to avoid excessive load times and numerous requests, since the service is not designed to support high-density real-time data delivery directly.

## License

- **Datasets:** Licensed by IDECA and Datos Abiertos Bogotá under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).  
  Attribution is required when using or redistributing the data.

- **Code:** This repository's scripts and configuration are licensed under the [MIT License](LICENSE).
