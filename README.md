# kafka-playground

Kubernetes - Apache Kafka playground using Kind and Strimzi Operator.

## Prerequisites

- Any Kubernetes cluster should work, but I prefer using Kind for local development.
  - [Docker](https://www.docker.com/products/docker-desktop/)
  - [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (Kubernetes in Docker)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/) (for installing Strimzi)
- OpenSSL and Keytool (for certificate generation)

> [!NOTE]
> Optional: Install [k9s](https://k9scli.io/) for a better Kubernetes CLI experience.

## Quick Start

1. Clone this repository

2. Make the cluster setup script executable:
    ```bash
    chmod +x setup-cluster.sh
    ```

3. Create the Kind cluster and deploy Strimzi operator:
    ```bash
    ./setup-cluster.sh
    ```

4. Deploy Kafka cluster:
    ```bash
    kubectl apply -f kafka/kafka-kraft.yaml
    kubectl wait kafka/demo --for=condition=Ready --timeout=300s -n kafka
    ```

5. Create Kafka topic:
    ```bash
    kubectl apply -f kafka/kafka-topic.yaml
    ```

6. Create Kafdrop user and certificates:
    - Create kafka user for Kafdrop:
        ```bash
        kubectl apply -f kafka/kafdrop-mtls-user.yaml
        ```

    - Create certs directory if not exists
        ```bash
        mkdir -p certs
        ```

    - Wait for user certificate to be created and then extract Kafka user and CA certificates
        - Wait for the secret to be created
            ```bash
            kubectl wait --for=condition=complete job/kafdrop-mtls-user -n kafka --timeout=300s
            ```

        - Extract the user certificate and CA certificate
            ```bash
            kubectl get secret kafdrop-mtls-user -n kafka -o jsonpath='{.data.user\.crt}' | base64 -d > certs/kafdrop-mtls-user.crt
            kubectl get secret kafdrop-mtls-user -n kafka -o jsonpath='{.data.user\.key}' | base64 -d > certs/kafdrop-mtls-user.key
            kubectl get secret demo-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.crt}' | base64 -d > certs/ca.crt
            ```

    - Create PKCS12 keystore for Kafdrop
        ```bash
        openssl pkcs12 -export \
        -in certs/kafdrop-mtls-user.crt \
        -inkey certs/kafdrop-mtls-user.key \
        -out certs/kafdrop-mtls-user.p12 \
        -name kafdrop-mtls-user \
        -CAfile certs/ca.crt \
        -caname root \
        -passout pass: < Your password >
        ```

    - Create a secret for Kafdrop with the PKCS12 keystore and CA certificate
        ```bash
        kubectl create secret generic kafdrop-mtls-cert-secret \
        --from-file=kafdrop-mtls-user.p12=certs/kafdrop-mtls-user.p12 \
        --from-file=ca.crt=certs/ca.crt \
        -n kafka
        ```

7. Configure Kafdrop deployment:
    - Create the base64 encoded value for `kafka.properties`:
        - The ssl.endpoint.identification.algorithm is set to an empty string to disable hostname verification. This is not recommended for production environments use "HTTPS" instead.
        - The keystore password should be the same as the one used in PKCS12 creation.

        ```bash
        echo -n "security.protocol=SSL
        ssl.keystore.type=PKCS12
        ssl.truststore.type=PEM
        ssl.endpoint.identification.algorithm=""
        ssl.keystore.location=/certs/kafdrop-mtls-user.p12
        ssl.keystore.password=""
        ssl.truststore.location=/certs/ca.crt" | base64
        ```

    - Replace the base64 encoded value in the Kafdrop deployment YAML file `kafka/kafdrop-mtls.yaml`:
        ```yaml
        # ...
        - name: KAFKA_PROPERTIES
            value: < Base64 encoded kafka.properties >
        # ...
        ```

8. Deploy Kafdrop:
    ```bash
    kubectl apply -f kafka/kafdrop-mtls.yaml
    ```

9. Get the node IP address:
    ```bash
    kubectl get nodes -o wide
    ```

10. Access Kafdrop:
    Open a web browser and navigate to `http://<any-node-ip>:30000`. You should see the Kafdrop UI.

## Cleanup

To delete the Kind cluster and all resources:

```bash
kind delete clusters kafka-playground
```
