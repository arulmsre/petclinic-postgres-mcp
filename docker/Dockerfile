# syntax=docker/dockerfile-upstream:master
FROM eclipse-temurin:17 as builder
WORKDIR application
ARG ARTIFACT_NAME
COPY ${ARTIFACT_NAME}.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

# syntax=docker/dockerfile-upstream:master
FROM eclipse-temurin:17
WORKDIR application
ARG EXPOSED_PORT
ARG ROLE_NAME
EXPOSE ${EXPOSED_PORT}
ENV SPRING_PROFILES_ACTIVE docker
# ENV APPLICATIONINSIGHTS_CONFIGURATION_FILE="../classes/applicationinsights.json"
# ENV APPLICATIONINSIGHTS_ROLE_NAME="${ROLE_NAME//spring-petclinic-/}"
# ENV DBLF_ENABLED="true"
# ENV JAVA_TOOL_OPTIONS="-javaagent:BOOT-INF/classes/dynamic-binded-logging-framework.jar"
# ENV JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -javaagent:BOOT-INF/lib/applicationinsights-agent-3.5.3.jar"
COPY --from=builder application/dependencies/ ./
# fix for https://stackoverflow.com/questions/51115856/docker-failed-to-export-image-failed-to-create-image-failed-to-get-layer
# (only last copy caused issue)
# this seems to be triggered by using btrfs:
# https://github.com/moby/moby/issues/36573
RUN true
COPY --from=builder application/spring-boot-loader/ ./
RUN true
COPY --from=builder application/snapshot-dependencies/ ./
RUN true
COPY --from=builder application/application/ ./
ENTRYPOINT ["java" ,"org.springframework.boot.loader.launch.JarLauncher"]