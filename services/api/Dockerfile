FROM golang:1.25-bookworm AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/ingestor ./cmd/ingestor && \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/feedcheck ./cmd/feedcheck

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
COPY --from=build /out/ingestor /ingestor
COPY --from=build /out/feedcheck /feedcheck
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
