resource "aws_codeartifact_domain" "fincorp" {
  domain = var.codeartifact_domain
}

resource "aws_codeartifact_repository" "npm_store" {
  domain     = aws_codeartifact_domain.fincorp.domain
  repository = "npm-store"

  external_connections {
    external_connection_name = "public:npmjs"
  }
}

resource "aws_codeartifact_repository" "fincorp_internal" {
  domain     = aws_codeartifact_domain.fincorp.domain
  repository = "fincorp-internal"

  upstream {
    repository_name = aws_codeartifact_repository.npm_store.repository
  }
}
