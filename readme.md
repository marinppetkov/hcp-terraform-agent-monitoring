# Telemetry

**This repository is used for setting up and testing HCP Terraform agent monitoring using Grafana and Prometheus**

[HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs/agents/telemetry)

### Overview
To configure your agent to emit telemetry data, you must include the -otlp-address flag or TFC_AGENT_OTLP_ADDRESS environment variable. This should be set to the host:port address of an OpenTelemetry collector. This address should be a gRPC server running an OLTP collector.


## Example: Using Docker Containers

### 1. Create a bridge network 
```bash
docker network create tfc_agent
```

### 2. Deploy OpenTelemetry container

[collector.yml](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/main/distributions/otelcol-contrib/config.yaml)
```bash
docker run -d --name opentel --network tfc_agent \
  --mount type=bind,source=${PWD}/collector.yml,target=/etc/otelcol-contrib/config.yaml \
  -p 127.0.0.1:4317:4317/tcp \
  otel/opentelemetry-collector-contrib:latest
```


### 3. Deploy Prometheus </br>
Prometheus container documentation </br>
 - [Installation Guide](https://prometheus.io/docs/prometheus/latest/installation/) </br>
 - [Configuration Guide](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#static_config) </br>

```bash
docker run -d --name prometh --network tfc_agent \
    -p 9090:9090 \
    --mount type=bind,source=${PWD}/prometheus.yml,target=/etc/prometheus/prometheus.yml \
    prom/prometheus
```

### 4. Start an HCP Terraform agent:
```bash
docker run -d --name tfc-agent --network tfc_agent \
-e TFC_AGENT_TOKEN=<token> \
-e TFC_AGENT_NAME=local_agent \
-e TFC_AGENT_OTLP_ADDRESS=opentel:4317 \
hashicorp/tfc-agent:latest
```

**Notes**
- A Docker Compose YAML file is available in the `./docker-compose` directory.</br>
Ensure the `AGENT_TOKEN` environment variable is set in advance.

- The above steps can be automated using an Azure Linux VM with the Terraform code located in the `./azure_vm` directory.

