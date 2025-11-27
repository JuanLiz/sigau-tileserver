FROM ghcr.io/osgeo/gdal:ubuntu-small-3.12.0 AS downloader
WORKDIR /build

ARG LOCALITIES_URL="https://datosabiertos.bogota.gov.co/dataset/856cb657-8ca3-4ee8-857f-37211173b1f8/resource/497b8756-0927-4aee-8da9-ca4e32ca3a8a/download/loca.geojson"
ARG SIGAU_URL="https://datosabiertos.bogota.gov.co/dataset/18721a34-0b1c-4399-bf2c-5f03fe5ef21a/resource/a351e008-aeaa-44c3-8920-d038776e9269/download/arboladourbano.geojson"

# Download GeoJSON files
RUN set -eux; \
    curl -fSL --retry 5 --retry-delay 5 --insecure \
        -o localities_raw.geojson "$LOCALITIES_URL" || true; \
    curl -fSL --retry 5 --retry-delay 5 --insecure \
        -o arboladourbano.geojson "$SIGAU_URL" || true

# Convert to EPSG:4326
RUN set -eux; \
    if [ -f arboladourbano.geojson ]; then \
        ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
            arboladourbano_wgs84.geojson arboladourbano.geojson && \
            rm -f arboladourbano.geojson || true; \
    fi; \
    if [ -f localities_raw.geojson ]; then \
        ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
            localities_wgs84.geojson localities_raw.geojson && \
            rm -f localities_raw.geojson || true; \
    fi


# Build mbtiles, only if there are converted GeoJSONs
FROM ghcr.io/osgeo/gdal:ubuntu-small-3.12.0 AS builder
WORKDIR /build

# Copy downloaded GeoJSONs
COPY --from=downloader /build/* /build/

# Install dependencies
RUN set -eux; \
    if [ -f arboladourbano_wgs84.geojson ] || \
       [ -f localities_wgs84.geojson ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            git \
            build-essential \
            ca-certificates \
            libsqlite3-dev \
            zlib1g-dev && \
        rm -rf /var/lib/apt/lists/*; \
        \
        # Install Tippecanoe
        git clone --depth 1 https://github.com/felt/tippecanoe.git && \
        cd tippecanoe && \
        make -j"$(nproc)" && make install && \
        cd .. && rm -rf tippecanoe; \
    else \
        echo "No converted GeoJSONs found; using fallback"; \
    fi

# Generate MBTiles
RUN set -eux; \
    mkdir -p /output; \
    if [ -f arboladourbano_wgs84.geojson ]; then \
        # Individual points
        if ! tippecanoe -o sigau.mbtiles \
            -l arboladourbano \
            --drop-densest-as-needed \
            --extend-zooms-if-still-dropping \
            --no-feature-limit \
            --no-tile-size-limit \
            --maximum-zoom=18 \
            --minimum-zoom=12 \
            --quiet \
            arboladourbano_wgs84.geojson; then \
            echo "sigau generation failed; removing partial"; \
            rm -f sigau.mbtiles || true; \
        else \
            mv -f sigau.mbtiles /output/; \
        fi; \
        # Clusters
        if ! tippecanoe -o sigau-clustered.mbtiles \
            --layer=clusters \
            --no-feature-limit \
            --no-tile-size-limit \
            --minimum-zoom=8 \
            --maximum-zoom=15 \
            --cluster-distance=40 \
            --cluster-maxzoom=15 \
            --cluster-densest-as-needed \
            --quiet \
            arboladourbano_wgs84.geojson; then \
            echo "sigau-clustered failed; removing partial"; \
            rm -f sigau-clustered.mbtiles || true; \
        else \
            mv -f sigau-clustered.mbtiles /output/; \
        fi; \
    fi; \
    # Localities
    if [ -f localities_wgs84.geojson ]; then \
        if ! tippecanoe -o localities.mbtiles \
            --layer=localities \
            --force \
            --no-feature-limit \
            --no-tile-size-limit \
            --minimum-zoom=0 \
            --maximum-zoom=18 \
            --coalesce-densest-as-needed \
            --extend-zooms-if-still-dropping \
            --quiet \
            localities_wgs84.geojson; then \
            echo "localities failed; removing partial"; \
            rm -f localities.mbtiles || true; \
        else \
            mv -f localities.mbtiles /output/; \
        fi; \
    fi


# Main tileserver
FROM maptiler/tileserver-gl:v5.4.0

# Copy pre-baked MBTiles as fallback and config file
ADD data /data
# Overwrite with freshly generated MBTiles
COPY --from=builder /output/*.mbtiles /data/

EXPOSE 8080
CMD ["--verbose"]