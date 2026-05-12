FROM alpine:3.22
RUN apk update && apk add vim nginx>=1.18.0
RUN addgroup -S myuser && adduser -S myuser -G myuser
COPY ./run.sh run.sh
RUN ["chmod", "+x", "./run.sh"]
USER myuser
ENTRYPOINT ["/bin/sh", "./run.sh"]
