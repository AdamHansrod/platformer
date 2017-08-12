FROM alpine:edge

RUN apk --update upgrade && apk add openjdk8-jre-base
RUN mkdir -p /opt/app/ && adduser -HD app

ADD scripts/startup.sh /opt/app/startup.sh

USER app
EXPOSE 8080

CMD ["/bin/sh", "/opt/app/startup.sh"]
