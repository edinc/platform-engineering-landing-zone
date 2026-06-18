{{- define "golden-path.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "golden-path.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "golden-path.name" . -}}
{{- end -}}
{{- end -}}

{{- define "golden-path.labels" -}}
app: {{ include "golden-path.name" . }}
app.kubernetes.io/name: {{ include "golden-path.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
team: {{ .Values.platform.team | quote }}
product: {{ .Values.platform.product | quote }}
costCenter: {{ .Values.platform.costCenter | quote }}
dataClassification: {{ .Values.platform.dataClassification | quote }}
confidentiality: {{ .Values.platform.confidentiality | quote }}
managedBy: {{ .Values.platform.managedBy | quote }}
{{- end -}}

{{- define "golden-path.selectorLabels" -}}
app.kubernetes.io/name: {{ include "golden-path.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "golden-path.podLabels" -}}
{{ include "golden-path.selectorLabels" . }}
app: {{ include "golden-path.name" . }}
team: {{ .Values.platform.team | quote }}
costCenter: {{ .Values.platform.costCenter | quote }}
dataClassification: {{ .Values.platform.dataClassification | quote }}
{{- end -}}

{{- define "golden-path.annotations" -}}
platform.example.io/repo: {{ .Values.platform.repo | quote }}
{{- end -}}
