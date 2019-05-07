FROM golang:1.11 AS build
ENV GO111MODULE=on
WORKDIR /go/src/github.com/Azure/aad-pod-identity
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download
COPY . ./

FROM build AS build-mic
ARG MIC_VERSION=0.0.0-dev
RUN make build-mic

FROM build AS build-nmi
ARG NMI_VERSION=0.0.0-dev
RUN make build-nmi

FROM build AS build-demo
ARG DEMO_VERSION=0.0.0-dev
RUN make build-demo

FROM build AS build-identityvalidator
ARG IDENTITY_VALIDATOR_VERSION=0.0.0-dev
RUN make build-identityvalidator

FROM alpine:3.8 AS base
RUN apk add --no-cache \
    ca-certificates \
    iptables \
    && update-ca-certificates

FROM base AS nmi
COPY --from=build-nmi /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/nmi /bin/
ENTRYPOINT ["nmi"]

FROM base AS mic
COPY --from=build-mic /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/mic /bin/
ENTRYPOINT ["mic"]

FROM base AS demo
COPY --from=build-demo /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/demo /bin/
ENTRYPOINT ["demo"]

FROM base AS identityvalidator
COPY --from=build-identityvalidator /go/src/github.com/Azure/aad-pod-identity/bin/aad-pod-identity/identityvalidator /bin/
ENTRYPOINT ["identityvalidator"]
