FROM docker:cli

RUN apk add --no-cache curl

COPY docker-telegram-alerts.sh /usr/local/bin/docker-telegram-alerts

RUN chmod +x /usr/local/bin/docker-telegram-alerts

ENTRYPOINT ["/usr/local/bin/docker-telegram-alerts"]