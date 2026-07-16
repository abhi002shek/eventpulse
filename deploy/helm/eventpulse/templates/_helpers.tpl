{{/*
Expand the chart name.
*/}}
{{- define "eventpulse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified app name.
*/}}
{{- define "eventpulse.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "eventpulse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eventpulse.labels" -}}
helm.sh/chart: {{ include "eventpulse.chart" . }}
app.kubernetes.io/name: {{ include "eventpulse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "eventpulse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eventpulse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "eventpulse.apiSelectorLabels" -}}
{{ include "eventpulse.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end -}}

{{- define "eventpulse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- include "eventpulse.fullname" . -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "eventpulse.image" -}}
{{- if not (regexMatch "^sha256:[0-9a-f]{64}$" .Values.image.digest) -}}
{{- fail "image.digest must be an immutable sha256 digest" -}}
{{- end -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- end -}}

{{- define "eventpulse.configChecksum" -}}
{{- printf "%s-%s-%s-%s-%s-%s-%v" .Values.config.appName .Values.config.serviceName .Values.config.environment .Values.config.logLevel .Values.database.host .Values.database.name .Values.database.port | sha256sum -}}
{{- end -}}

{{- define "eventpulse.secretName" -}}
{{- .Values.database.secret.name -}}
{{- end -}}

{{- define "eventpulse.postgresName" -}}
{{- printf "%s-postgres" (include "eventpulse.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
