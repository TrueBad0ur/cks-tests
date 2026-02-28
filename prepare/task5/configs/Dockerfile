FROM ubuntu:18.04

RUN apt-get update && apt-get install -y python3 \
    && useradd -m appuser

WORKDIR /app

COPY . .

RUN chmod 777 /app

EXPOSE 8000

USER root

CMD ["python3", "app.py"]
