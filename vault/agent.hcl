pid_file = "/vault/agent/pidfile"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/vault/agent/role_id"
      secret_id_file_path = "/vault/agent/secret_id"
    }
  }
  sink "file" {
    config = {
      path = "/vault/agent/token"
    }
  }
}

template {
  source = "/vault/templates/aws_ssh_key.tpl"
  destination = "/vault/secrets/aws_ssh_key.pem"
  perms = "0600"
}
