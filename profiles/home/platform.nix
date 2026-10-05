{ pkgs, ... }:
{
  # Eligibility and CLI installation do not start local infrastructure workloads.
  home.packages = with pkgs; [
    opentofu
    terragrunt
    kubectl
    kubernetes-helm
    k9s
    kustomize
    kubectx
    stern
    trivy
    syft
    grype
    cosign
    dive
    gitleaks
    sops
    age
    nmap
    mtr
    iperf3
    dnsutils
    bind.host
    tcpdump
    fd
    yq-go
    just
    watchexec
    hyperfine
    nvd
  ];
}
