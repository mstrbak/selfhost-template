# Centralised port registry. Append next free number when adding a service.
# Standard ports kept at conventional numbers; app ports sequential from 8001.
# Next free port: 8004
{
  # Standard
  traefikHttp  = 80;
  traefikHttps = 443;

  # Application ports
  homepage    = 8001;
  vaultwarden = 8002;
  immich      = 2283;  # conventional Immich port
  opencloud   = 9200;  # conventional OpenCloud port
  onlyoffice  = 8003;  # internal port we route to via Traefik
  searxng     = 8004;
  excalidraw  = 8005;
  portainer   = 9000;
  ittools     = 8006;
  stirlingPdf = 8007;
  # Next free port: 8008
}
