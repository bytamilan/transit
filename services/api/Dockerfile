FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/ingestor ./cmd/ingestor && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/feedcheck ./cmd/feedcheck && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/tracker ./cmd/tracker && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/exporter ./cmd/exporter
# Pre-created here (distroless's final stage has no shell/mkdir to do this
# itself) so the COPY --chown below seeds deploy/compose/compose.yaml's
# exporter_data named volume with nonroot ownership on first creation —
# without this, Docker creates a fresh named volume owned by root, and the
# nonroot exporter process can never write its own GTFS.zip output there.
RUN mkdir -p /data/exports

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
COPY --from=build /out/ingestor /ingestor
COPY --from=build /out/feedcheck /feedcheck
COPY --from=build /out/tracker /tracker
COPY --from=build /out/exporter /exporter
COPY --from=build --chown=nonroot:nonroot /data/exports /data/exports
USER nonroot:nonroot
EXPOSE 8080
# CMD, not ENTRYPOINT: deploy/compose/compose.yaml's ingestor/tracker/
# exporter services set `command: ["/ingestor"]` etc. to select a
# different binary from this same image. A fixed ENTRYPOINT would make
# that `command:` just an argument appended to /server (which silently
# ignores it and starts the API server anyway) instead of replacing it —
# exactly the bug this comment exists to prevent regressing.
CMD ["/server"]
