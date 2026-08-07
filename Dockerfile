FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache jq util-linux coreutils cronie

WORKDIR /app

# Copy scripts (ensure they are executable)
COPY run.sh services.sh ./
RUN chmod +x run.sh services.sh

# Default command: run script (note: to read real NIC stats, mount /sys/class/net into container)
CMD ["/bin/sh","-c","./run.sh"]
