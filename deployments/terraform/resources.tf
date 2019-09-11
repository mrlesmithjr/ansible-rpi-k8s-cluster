resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_deployment" "nginx-metallb-demo" {
  metadata {
    annotations = {}
    namespace   = "demo"
    name        = "nginx-metallb-demo"
    labels      = {}
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx-metallb-demo"
      }
    }
    template {
      metadata {
        annotations = {}
        labels = {
          app = "nginx-metallb-demo"
        }
      }
      spec {
        container {
          args    = []
          command = []
          name    = "nginx"
          image   = "mrlesmithjr/nginx-arm:alpine"
          port {
            container_port = 80
            host_port      = 0
            name           = "http"
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx-metallb-demo" {
  metadata {
    name      = "nginx-metallb-demo"
    namespace = "demo"
  }
  spec {
    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }
    selector = {
      app = "nginx-metallb-demo"
    }
    type = "LoadBalancer"
  }
}
