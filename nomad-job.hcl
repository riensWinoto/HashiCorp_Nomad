job "pdp" {
  region = "global"
  datacenters = ["*"]
  type = "service"

  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
  }

  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "vault-eaas" {
    count = 1
    network {
      port "http" {
        static = 8200
        to = 8200
      }
    }

    volume "vault_dir" {
      type = "host"
      read_only = false
      source = "vault_dir"
    }

    service {
      name     = "vault-api"
      tags     = ["eaas", "vault"]
      port     = "http"
      provider = "nomad"

      check {
        name     = "vault-api-hc"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }

    }

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    task "vault" {
      driver = "docker"
      volume_mount {
        volume = "vault_dir"
        destination = "/vault"
      }

      template {
        data = <<EOH
ui = true
disable_mlock = true
storage "raft" {
  path = "/vault"
  #node_id = "num_1"
}

# HTTPS listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = 1
  #tls_cert_file = "/opt/vault/tls/tls.crt"
  #tls_key_file  = "/opt/vault/tls/tls.key"
}

api_addr = "http://localhost:8200"
cluster_addr = "http://localhost:8201"
EOH
        destination = "/local/vault-config.hcl"
      }

      config {
        image = "vault:1.13.0"
        ports = ["http"]
        auth_soft_fail = true
        entrypoint = ["vault", "server", "-config=/local/vault-config.hcl"]
      }

      identity {
        env  = true
        file = true
      }

      resources {
        cpu    = 1000 # 500 MHz
        memory = 512 # 256MB
      }
    }
  }
}