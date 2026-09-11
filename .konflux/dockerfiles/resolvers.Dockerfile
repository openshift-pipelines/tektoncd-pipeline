ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:latest@sha256:5e68f09a652ac6627a83c57655e42e24575efb278b54336039c9308607fc6b21
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal@sha256:d235f607e1d6d833f031db107dc42206e4dd4d5aa9142c43d3771fb7f9bea76a

FROM $RUNTIME as dependency-builder

COPY dependencies/tini dependencies/tini
WORKDIR /dependencies/tini
RUN microdnf update && microdnf install -y cmake gcc
ENV ENV CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
RUN cmake . && make tini

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/resolvers \
    ./cmd/resolvers

FROM $RUNTIME
ARG VERSION=1.22

ENV RESOLVERS=/usr/local/bin/resolvers \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/resolvers /ko-app/resolvers
COPY head ${KO_DATA_PATH}/HEAD

COPY --from=dependency-builder /dependencies/tini/tini /sbin/tini
RUN chmod 0755 /sbin/tini && chown root:root /sbin/tini

LABEL \
    com.redhat.component="openshift-pipelines-resolvers-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.22::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,resolvers" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-resolvers-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    version="v1.22.6"

RUN microdnf update && microdnf install -y git && microdnf clean all

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/sbin/tini", "--", "/ko-app/resolvers"]

