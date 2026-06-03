# Centralised port registry. Append next free number when adding a service.
# Standard ports kept at conventional numbers; app ports sequential from 8001.
# Next free port: 8003
{
  # Standard
  traefikHttp  = 80;
  traefikHttps = 443;

  # Application ports
  homepage    = 8001;
  vaultwarden = 8002;
  # Next free port: 8003
}
