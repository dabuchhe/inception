FROM debian:stable-slim

RUN apt-get update \
    && apt-get install -y python3 \
    && rm -rf /var/lib/apt/lists/*

COPY index.html /site/index.html

CMD ["python3", "-m", "http.server", "8000", "--directory", "/site"]