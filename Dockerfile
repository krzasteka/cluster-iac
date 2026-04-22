FROM hashicorp/terraform:latest

# Override HashiCorp's default entrypoint so Docker Compose commands work normally
ENTRYPOINT []

RUN apk add --no-cache ansible openssh-client git py3-pip
RUN ansible-galaxy collection install community.general

WORKDIR /infra
