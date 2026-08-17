{
  backend = {
    hostname = "127.0.0.1";
    port = 4096;
  };

  auth = {
    username = "opencode";
    envFile = ".config/opencode-remote/server.env";
  };

  serve = {
    httpsPort = 443;
  };
}
