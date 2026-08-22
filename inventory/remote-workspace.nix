{
  backend = {
    hostname = "127.0.0.1";
    port = 8082;
  };

  serve = {
    httpsPort = 443;
  };

  configFile = ".config/remote-workspace/zellij.kdl";
}
