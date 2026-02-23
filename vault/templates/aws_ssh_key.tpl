{{- with secret "secret/data/aws/ssh" -}}
{{ .Data.data.private_key }}
{{- end -}}
