ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:23c7cb17e9c53a65f9ab01f2edf1a4e07c9a9dc2258ed63d69e06925e7cea381
ARG UBI_RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:08d4c70f1baf6537a0728656cf7942d561e74a35916509d205b6519861266352

FROM $UBI_RUNTIME as dependency-builder

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

FROM $UBI_RUNTIME
ARG VERSION=1.23

ENV RESOLVERS=/usr/local/bin/resolvers \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/resolvers /ko-app/resolvers
COPY head ${KO_DATA_PATH}/HEAD

COPY --from=dependency-builder /dependencies/tini/tini /sbin/tini
RUN chmod 0755 /sbin/tini && chown root:root /sbin/tini

LABEL \
    com.redhat.component="openshift-pipelines-resolvers-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.23::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,resolvers" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-resolvers-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline resolvers" \
    version="v1.23.5"

RUN microdnf update && microdnf install -y git && microdnf clean all

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/sbin/tini", "--", "/ko-app/resolvers"]

