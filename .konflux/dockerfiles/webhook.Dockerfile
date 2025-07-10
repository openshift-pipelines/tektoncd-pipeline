ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:22fc585d8eebbfca4286a8daa879eeddd3c9ee05c9a35647c8b480d6a50eca4e

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/webhook \
    ./cmd/webhook

FROM $RUNTIME
ARG VERSION=pipeline-1.17.2

ENV WEBHOOK=/usr/local/bin/webhook \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/webhook /ko-app/webhook
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-webhook-rhel8-container" \
      name="openshift-pipelines/pipelines-webhook-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Webhook" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Webhook" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Webhook" \
      io.k8s.description="Red Hat OpenShift Pipelines Webhook" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/webhook"]
