FROM alpine:latest
RUN apk add --no-cache terraform ansible openssh-client git py3-pip
RUN ansible-galaxy collection install community.general
WORKDIR /infra
