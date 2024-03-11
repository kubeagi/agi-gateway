{{/*
cluster reader serviceaccount name
*/}}
{{- define "global.clusterReaderName" -}}
{{- if .Values.global.clusterReaderNameOverride -}}
{{- .Values.global.clusterReaderNameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- if .Values.global.host -}}
host-cluster-reader
{{- else -}}
managed-cluster-reader
{{- end }}
{{- end }}
{{- end }}

{{/*
cluster reader serviceaccount namespace
*/}}
{{- define "global.clusterReaderNamespace" -}}
{{- if .Values.global.clusterReaderNameSpaceOverride -}}
{{- .Values.global.clusterReaderNameSpaceOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
u4a-system
{{- end }}
{{- end }}
