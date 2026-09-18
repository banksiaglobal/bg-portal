ARG IMAGE=containers.intersystems.com/intersystems/iris-community:latest-preview
FROM $IMAGE

WORKDIR /home/irisowner/irisbuild
USER root
RUN mkdir -p /usr/irissys/csp/portal && chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /usr/irissys/csp/portal
USER ${ISC_PACKAGE_MGRUSER}

RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly
