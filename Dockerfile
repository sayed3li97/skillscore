# skillscore in a container, for any container-based CI runner
# (GitLab CI, Google Cloud Build, Drone, Woodpecker) and for the
# pre-commit `skillscore-docker` hook.
#
# Build:  docker build -t skillscore .
# Score:  docker run --rm -v "$PWD:/work" -w /work skillscore skills/ --min-score 80
#
# This installs the published package from pub.dev, so the image always
# matches a released version. For a smaller image you can instead compile a
# native binary from source (dart compile exe bin/skillscore.dart) into a
# debian:stable-slim stage.
FROM dart:stable

# Install the published CLI. Pass --build-arg VERSION=0.8.0 to pin a version.
ARG VERSION=""
RUN if [ -n "$VERSION" ]; then \
      dart pub global activate skillscore "$VERSION"; \
    else \
      dart pub global activate skillscore; \
    fi
ENV PATH="/root/.pub-cache/bin:${PATH}"

WORKDIR /work
ENTRYPOINT ["skillscore"]
CMD ["--help"]
