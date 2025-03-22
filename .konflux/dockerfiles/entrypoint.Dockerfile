ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=registry.access.redhat.com/ubi8/ubi-minimal@sha256:33161cf5ec11ea13bfe60cad64f56a3aa4d893852e8ec44b2fd2a6b40cc38539

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV CHANGESET_REV=$CI_PIPELINE_UPSTREAM_COMMIT
ENV GODEBUG="http2server=0"
RUN CGO_ENABLED=0 \
    go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/entrypoint \
    ./cmd/entrypoint

FROM $RUNTIME
ARG VERSION=pipeline-next

ENV ENTRYPOINT=/usr/local/bin/entrypoint \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/entrypoint /ko-app/entrypoint
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-entrypoint-rhel8-container" \
      name="openshift-pipelines/pipelines-entrypoint-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Entrypoint" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Entrypoint" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Entrypoint" \
      io.k8s.description="Red Hat OpenShift Pipelines Entrypoint" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/entrypoint"]
