FROM anapsix/alpine-java:8_jdk

# Let's assume all our apps will need jdk8
RUN apk --update upgrade && \
     apk add --update curl && \
     rm -rf /var/cache/apk/*

RUN mkdir -p /opt/app/
RUN mkdir -p /opt/app/config
RUN mkdir -p /opt/app/source
RUN mkdir -p /opt/app/files

RUN adduser -h /opt/app -D app

COPY scripts/startup.sh /opt/app/startup.sh
RUN chown -R app:app /opt/app
RUN chmod -R 777 /opt/app

USER app
EXPOSE 8080

ENTRYPOINT ["/opt/app/startup.sh"]
