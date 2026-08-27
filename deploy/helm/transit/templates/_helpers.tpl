{{- define "transit.name" -}}
transit
{{- end -}}

{{- define "transit.fullname" -}}
{{- .Release.Name }}-transit
{{- end -}}

{{- define "transit.labels" -}}
app.kubernetes.io/name: {{ include "transit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "transit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "transit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "transit.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end -}}

{{/*
Shared env vars every services/api binary reads (a subset — each
Deployment adds its own binary-specific vars on top of this list).
*/}}
{{- define "transit.commonEnv" -}}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.config.otelExporterOTLPEndpoint | quote }}
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ .Values.config.otelTracesSamplerArg | quote }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: DATABASE_URL
{{- end -}}
