ARG IMAGE=containers.intersystems.com/intersystems/iris-community:latest-preview
FROM $IMAGE

WORKDIR /home/irisowner/irisbuild
USER root
RUN mkdir -p /usr/irissys/csp/portal && chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /usr/irissys/csp/portal
USER ${ISC_PACKAGE_MGRUSER}

# Set by the GitHub Actions workflow; when building there, modules are also published to GHCR.
ARG GITHUB_ACTIONS
ARG GH_USERNAME
ARG GH_NAMESPACE

RUN --mount=type=bind,src=.,dst=. \
    --mount=type=secret,id=gh_token,mode=0444 \
    iris start IRIS && \
    iris session IRIS < iris.script && \
    if [ "$GITHUB_ACTIONS" = "true" ] && [ -s /run/secrets/gh_token ]; then \
      PUBLISH_MODULES="$(find . -name module.xml -not -path '*/node_modules/*' -exec grep -m1 -o '<Name>[^<]*</Name>' {} \; | sed -e 's:</*Name>::g' | tr '\n' ' ')" \
      GH_TOKEN="$(cat /run/secrets/gh_token)" \
      iris session IRIS < publish.script; \
    fi && \
    iris stop IRIS quietly
