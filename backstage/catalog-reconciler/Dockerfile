FROM docker.io/library/python@sha256:6e86e32da1c9df234051a7cb4e6a8eff89cebc457da8dec8890fc4f376d6053d

USER 65532:65532
WORKDIR /opt/reconciler
COPY --chown=65532:65532 reconciler.py /opt/reconciler/reconciler.py

ENTRYPOINT ["python", "/opt/reconciler/reconciler.py"]
