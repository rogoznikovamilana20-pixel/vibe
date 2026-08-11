FROM alpine:latest

ARG PB_VERSION=0.22.19
RUN apk add --no-cache \
    unzip \
    ca-certificates \
    python3 \
    py3-pip \
    bash \
    git \
    git-lfs

# Install huggingface_hub for syncing
RUN pip install --no-cache-dir huggingface_hub[cli] --break-system-packages

# Download PocketBase
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/ && rm /tmp/pb.zip

# Create a non-root user (HF requires UID 1000)
RUN adduser -D -u 1000 user
ENV HOME=/home/user
WORKDIR $HOME/app
RUN chown -R user:user /pb $HOME/app

COPY --chown=user:user start.sh .
RUN chmod +x start.sh

USER user
EXPOSE 7860

CMD ["./start.sh"]
