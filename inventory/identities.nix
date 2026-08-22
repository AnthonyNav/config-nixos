{
  githubFallback = "https";

  identities = {
    personal = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "anthonydevxp@gmail.com";
      };
      roots = [
        "personal/"
        "nixos-config/"
      ];
      sshKey = ".ssh/id_personal";
      github = {
        alias = "github.com-personal";
        compatibilityAliases = [ ];
        namespaces = [ "AnthonyNav" ];
      };
    };

    work = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "antonio.zempoaltecatl@cargomovil.com";
      };
      roots = [ "work/" ];
      sshKey = ".ssh/id_work";
      github = {
        alias = "github.com-work";
        compatibilityAliases = [ "github.com-kigo" ];
        namespaces = [ "kigo" ];
      };
    };
  };
}
