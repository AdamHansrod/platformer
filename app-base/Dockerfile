FROM alpine:edge

# Let's assume all our apps will need jdk8
RUN apk --update upgrade && \
     apk add openjdk8-jre-base && \
     apk add --update curl && \
     rm -rf /var/cache/apk/*

RUN mkdir -p /opt/app/
RUN adduser -HD app

COPY scripts/startup.sh /opt/app/startup.sh
RUN chown -R app:app /opt/app
RUN chmod 777 /opt/app/startup.sh

USER app
EXPOSE 8080

ENTRYPOINT ["/opt/app/startup.sh"]
