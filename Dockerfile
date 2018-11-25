FROM rhel7:latest

ADD demo-admission-webhook /demo-admission-webhook
ENTRYPOINT ["./demo-admission-webhook"]
EXPOSE 8443
