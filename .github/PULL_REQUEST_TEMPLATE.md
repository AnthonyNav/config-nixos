## Summary

Describe the user-visible configuration change and why it belongs in this repository.

## Scope

- [ ] Shared configuration
- [ ] Victus
- [ ] Desktop
- [ ] ThinkPad
- [ ] Flake input update
- [ ] Documentation only

## Validation

- [ ] `nix fmt`
- [ ] `nix flake check --no-build --no-write-lock-file`
- [ ] Relevant host build(s)
- [ ] Real-session validation, when graphical behavior changed

## Safety

- [ ] No secrets, credentials, or generated local state are included
- [ ] This PR does not make a host-specific assumption in a shared module
