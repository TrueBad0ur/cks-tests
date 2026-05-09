# Original v1 Dockerfile (reference — do not modify this file)
# Actual Dockerfile is at /opt/course/16/image/Dockerfile on the exam node.
#
# Task: edit the Dockerfile to:
#   1. Change base image to alpine:3.22
#   2. Remove curl installation
#   3. Update nginx version constraint to >=1.18.0
#   4. Run main process as user "myuser"
#   Do NOT add new lines — only edit existing ones.

FROM alpine:3.20

RUN adduser -D myuser && \
    apk add --no-cache nginx>=1.14.0 curl

COPY index.html /usr/share/nginx/html/

USER myuser

ENTRYPOINT ["nginx", "-g", "daemon off;"]
