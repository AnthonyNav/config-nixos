_: {
  # Apple M5, 16 GiB RAM. Leave room for the editor, simulators and local work.
  nix.settings = {
    max-jobs = 2;
    cores = 2;
  };
}
