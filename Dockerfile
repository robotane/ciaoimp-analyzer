# Environnement complet du pipeline ciaoimp-analyzer :
# CiaoPP (expansion xsyntax), SWI-Prolog (transformations, TNF),
# GNU Prolog (CasLog), JDK (VM TNF + Prolog Cafe), Python 3.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 swi-prolog-nox gprolog openjdk-21-jdk-headless \
        curl ca-certificates build-essential git \
    && rm -rf /var/lib/apt/lists/*

# Ciao est installé sous un utilisateur non-root (uid 1000), pour que les
# fichiers écrits dans les volumes montés appartiennent à l'utilisateur hôte.
RUN userdel -r ubuntu 2>/dev/null || true; useradd -m -u 1000 -s /bin/bash app
USER app
WORKDIR /home/app
SHELL ["/bin/bash", "-c"]

# Ciao (binaires précompilés) puis CiaoPP, absent de l'installation minimale.
RUN curl -sSfL https://ciao-lang.org/boot | sh -s -- --prebuilt-bin local-install \
    && eval "$(~/.ciaoroot/v*/build/bin/ciao-env --sh)" \
    && ciao get ciaopp

COPY --chown=app:app docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chown=app:app . /app
WORKDIR /app

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["python3", "pipeline.py"]
