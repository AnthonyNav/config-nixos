{
  default = "work";

  identities = {
    personal = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "anthonydevxp@gmail.com";
      };
      roots = [
        "projects/"
        "nixos-config/"
      ];
      sshKey = ".ssh/id_personal";
      github = {
        alias = "github.com-personal";
      };
      aws.profile = "personal-readonly";
    };

    work = {
      git = {
        name = "Antonio Zempoaltecatl";
        email = "antonio.zempoaltecatl@cargomovil.com";
      };
      roots = [ ];
      sshKey = ".ssh/id_work";
      github = {
        alias = "github.com-work";
        compatibilityAliases = [ "github.com-kigo" ];
      };
      aws.profile = "work-readonly";
    };
  };
}
