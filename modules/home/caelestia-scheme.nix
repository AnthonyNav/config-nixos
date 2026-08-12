{ inputs, pkgs, ... }:

let
  # La CLI real de Caelestia (mismo paquete que usaría por default
  # programs.caelestia.cli.package, ver el flake de caelestia-shell:
  # cli-default = self.inputs.caelestia-cli.packages.${system}.default en su
  # nix/hm-module.nix). La resolvemos explícitamente para poder envolverla.
  realCli =
    inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # El switch claro/oscuro del panel de Caelestia (WallpaperAndStyle.qml ->
  # Colours.setMode() -> `caelestia scheme set --notify -m <mode>`, ver
  # services/Colours.qml en caelestia-shell) SOLO manda `--mode`, sin
  # `--flavour`/`--name`. Pero en Catppuccin, "mocha" únicamente tiene modo
  # dark y "latte" únicamente modo light: son flavours DISTINTOS, no una sola
  # paleta con ambos modos (ver data/schemes/catppuccin/{mocha,latte}/ en
  # caelestia-cli). Sin este wrapper, ese `-m light` truena con ValueError
  # ("does not have a light mode") antes de aplicar nada — ni el postHook
  # llega a correr. Como scheme_data_dir vive en el store de solo lectura, no
  # se puede "fusionar" ahí; la única salida es interceptar la llamada aquí.
  #
  # Este wrapper SOLO reescribe `caelestia scheme set` cuando trae `-m/--mode`
  # y NO trae ya `-f/--flavour` ni `-n/--name` (ese es exactamente el caso del
  # panel); le inyecta el flavour Catppuccin correcto para el modo pedido.
  # Cualquier otra invocación (incluida la que ya usa theme-sync.nix, que
  # siempre pasa --name/--flavour explícitos) pasa intacta al binario real.
  modeWrapper = pkgs.writeShellScript "caelestia-mode-wrapper" ''
    set -euo pipefail
    real="${realCli}/bin/caelestia"

    if [[ "''${1:-}" == "scheme" && "''${2:-}" == "set" ]]; then
      shift 2
      args=("$@")
      mode=""
      has_flavour=false
      has_name=false
      rest=()
      i=0
      while [[ $i -lt ''${#args[@]} ]]; do
        arg="''${args[$i]}"
        case "$arg" in
          -m|--mode)
            mode="''${args[$((i + 1))]}"
            rest+=("$arg" "$mode")
            i=$((i + 2))
            ;;
          --mode=*)
            mode="''${arg#*=}"
            rest+=("$arg")
            i=$((i + 1))
            ;;
          -f|--flavour)
            has_flavour=true
            rest+=("$arg" "''${args[$((i + 1))]}")
            i=$((i + 2))
            ;;
          --flavour=*)
            has_flavour=true
            rest+=("$arg")
            i=$((i + 1))
            ;;
          -n|--name)
            has_name=true
            rest+=("$arg" "''${args[$((i + 1))]}")
            i=$((i + 2))
            ;;
          --name=*)
            has_name=true
            rest+=("$arg")
            i=$((i + 1))
            ;;
          *)
            rest+=("$arg")
            i=$((i + 1))
            ;;
        esac
      done

      if [[ -n "$mode" && "$has_flavour" == false && "$has_name" == false ]]; then
        case "$mode" in
          light) rest+=("--name" "catppuccin" "--flavour" "latte") ;;
          dark) rest+=("--name" "catppuccin" "--flavour" "mocha") ;;
        esac
      fi

      exec "$real" scheme set "''${rest[@]}"
    fi

    exec "$real" "$@"
  '';

  # Reemplaza SOLO bin/caelestia por el wrapper; el resto del paquete
  # (completions de fish, etc.) sigue siendo el original vía symlinkJoin.
  wrappedCli = pkgs.symlinkJoin {
    name = "caelestia-cli-catppuccin-mode-wrapper";
    paths = [ realCli ];
    postBuild = ''
      rm "$out/bin/caelestia"
      ln -s ${modeWrapper} "$out/bin/caelestia"
    '';
  };

  # `programs.caelestia.cli.package` (abajo) sólo cambia qué `caelestia` se
  # instala en home.packages (el que usan una terminal nueva, el bind de
  # Hyprland, etc.) — el propio *binario del shell* NO lo usa. El paquete
  # `caelestia-shell` (variante "with-cli", ver flake.nix de caelestia-shell:
  # `with-cli = caelestia-shell.override { withCli = true; }`, usada como
  # default de `programs.caelestia.package`) se construye con
  # `makeWrapper ... --prefix PATH : "${lib.makeBinPath runtimeDeps}"`
  # (nix/default.nix), y `runtimeDeps` incluye la CLI **sin envolver**
  # (`caelestia-cli` tal cual la pasa el flake, antes de cualquier override
  # nuestro) porque así la compiló upstream. Ese `--prefix PATH` se antepone
  # al PATH heredado del proceso — así que el switch claro/oscuro del panel
  # (que corre `Quickshell.execDetached(["caelestia", ...])` DENTRO de ese
  # proceso) siempre encontraba la CLI real sin envolver primero, ignorando
  # nuestro wrapper del perfil general (confirmado: el PATH del proceso
  # `caelestia-shell` en vivo listaba la ruta de la CLI real ANTES que
  # `/etc/profiles/per-user/<user>/bin`). Por eso los comandos de terminal y
  # el atajo de Hyprland (que sí resuelven contra el PATH del perfil) ya
  # funcionaban, pero el switch del panel no.
  #
  # Fix: reconstruir la variante "with-cli" pasándole NUESTRA CLI envuelta en
  # el mismo argumento (`caelestia-cli`) que el flake usa para ese
  # runtimeDeps, en vez de tocar algo después de compilado.
  wrappedShell =
    (inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-shell.override {
      withCli = true;
      caelestia-cli = wrappedCli;
    }).overrideAttrs
      (old: {
        # Corrige el flujo Wi-Fi compartido por Nexus y el popout: conserva la
        # red activa hasta confirmar el reemplazo, usa UUID para perfiles
        # guardados y no fija redes visibles a un BSSID.
        patches = (old.patches or [ ]) ++ [
          (pkgs.writeText "caelestia-wifi-connection-flow.patch" ''
            diff --git a/modules/bar/popouts/Network.qml b/modules/bar/popouts/Network.qml
            --- a/modules/bar/popouts/Network.qml
            +++ b/modules/bar/popouts/Network.qml
            @@ -18,6 +18,7 @@ ColumnLayout {
                 property string view: "wireless" // "wireless" or "ethernet"
                 property var passwordNetwork: null
                 property bool showPasswordDialog: false
            +    property string connectionError: ""

                 spacing: Tokens.spacing.small
                 width: Tokens.sizes.bar.networkWidth
            @@ -50,6 +51,17 @@ ColumnLayout {
                     font: Tokens.font.body.small
                 }

            +    StyledText {
            +        visible: root.view === "wireless" && root.connectionError.length > 0
            +        Layout.preferredHeight: visible ? implicitHeight : 0
            +        Layout.fillWidth: true
            +        Layout.rightMargin: Tokens.padding.extraSmall
            +        text: root.connectionError
            +        color: Colours.palette.m3error
            +        font: Tokens.font.body.small
            +        wrapMode: Text.WordWrap
            +    }
            +
                 Repeater {
                     visible: root.view === "wireless"
                     model: ScriptModel {
            @@ -133,11 +145,16 @@ ColumnLayout {
                                         Nmcli.disconnectFromNetwork();
                                     } else {
                                         root.connectingToSsid = networkItem.modelData.ssid;
            +                            root.connectionError = "";
                                         NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                                             // Password is required - show password dialog
                                             root.passwordNetwork = network;
                                             root.showPasswordDialog = true;
                                             root.popouts.currentName = "wirelesspassword";
            +                            }, result => {
            +                                root.connectingToSsid = "";
            +                                if (result && !result.success && !result.needsPassword)
            +                                    root.connectionError = result.error || qsTr("Connection failed");
                                         });

                                         // Clear connecting state if connection succeeds immediately (saved profile)
            diff --git a/modules/bar/popouts/WirelessPassword.qml b/modules/bar/popouts/WirelessPassword.qml
            --- a/modules/bar/popouts/WirelessPassword.qml
            +++ b/modules/bar/popouts/WirelessPassword.qml
            @@ -18,39 +18,6 @@ ColumnLayout {

                 readonly property bool shouldBeVisible: root.popouts.currentName === "wirelesspassword"

            -    function checkConnectionStatus(): void {
            -        if (!root.shouldBeVisible || !connectButton.connecting) {
            -            return;
            -        }
            -
            -        // Check if we're connected to the target network (case-insensitive SSID comparison)
            -        const isConnected = root.network && Nmcli.active && Nmcli.active.ssid && Nmcli.active.ssid.toLowerCase().trim() === root.network.ssid.toLowerCase().trim();
            -
            -        if (isConnected) {
            -            // Successfully connected - give it a moment for network list to update
            -            // Use Timer for actual delay
            -            connectionSuccessTimer.start();
            -            return;
            -        }
            -
            -        // Check for connection failures - if pending connection was cleared but we're not connected
            -        if (Nmcli.pendingConnection === null && connectButton.connecting) {
            -            // Wait a bit more before giving up (allow time for connection to establish)
            -            if (connectionMonitor.repeatCount > 10) {
            -                connectionMonitor.stop();
            -                connectButton.connecting = false;
            -                connectButton.hasError = true;
            -                connectButton.enabled = true;
            -                connectButton.text = qsTr("Connect");
            -                passwordContainer.passwordBuffer = "";
            -                // Delete the failed connection
            -                if (root.network && root.network.ssid) {
            -                    Nmcli.forgetNetwork(root.network.ssid);
            -                }
            -            }
            -        }
            -    }
            -
                 function closeDialog(): void {
                     if (isClosing) {
                         return;
            @@ -61,7 +28,6 @@ ColumnLayout {
                     connectButton.connecting = false;
                     connectButton.hasError = false;
                     connectButton.text = qsTr("Connect");
            -        connectionMonitor.stop();

                     // Return to network popout
                     if (root.popouts.currentName === "wirelesspassword") {
            @@ -512,111 +478,22 @@ ColumnLayout {

                                     // Set connecting state
                                     connecting = true;
            -                        enabled = false;
                                     text = qsTr("Connecting...");

            -                        // Connect to network
                                     NetworkConnection.connectWithPassword(root.network, password, result => {
            -                            if (result && result.success)
            -                            // Connection successful, monitor will handle the rest
            -                            {} else if (result && result.needsPassword) {
            -                                // Shouldn't happen since we provided password
            -                                connectionMonitor.stop();
            -                                connecting = false;
            -                                hasError = true;
            -                                enabled = true;
            -                                text = qsTr("Connect");
            -                                passwordContainer.passwordBuffer = "";
            -                                // Delete the failed connection
            -                                if (root.network && root.network.ssid) {
            -                                    Nmcli.forgetNetwork(root.network.ssid);
            -                                }
            +                            connecting = false;
            +                            text = qsTr("Connect");
            +                            if (result && result.success) {
            +                                root.closeDialog();
                                         } else {
            -                                // Connection failed immediately - show error
            -                                connectionMonitor.stop();
            -                                connecting = false;
                                             hasError = true;
            -                                enabled = true;
            -                                text = qsTr("Connect");
                                             passwordContainer.passwordBuffer = "";
            -                                // Delete the failed connection
            -                                if (root.network && root.network.ssid) {
            -                                    Nmcli.forgetNetwork(root.network.ssid);
            -                                }
                                         }
                                     });
            -
            -                        // Start monitoring connection
            -                        connectionMonitor.start();
                                 }
                             }
                         }
                     }
                 }

            -    Timer {
            -        id: connectionMonitor
            -
            -        property int repeatCount: 0
            -
            -        interval: 1000
            -        repeat: true
            -        triggeredOnStart: false
            -
            -        onTriggered: {
            -            repeatCount++;
            -            root.checkConnectionStatus();
            -        }
            -
            -        onRunningChanged: {
            -            if (!running) {
            -                repeatCount = 0;
            -            }
            -        }
            -    }
            -
            -    Timer {
            -        id: connectionSuccessTimer
            -
            -        interval: 500
            -        onTriggered: {
            -            // Double-check connection is still active
            -            if (root.shouldBeVisible && Nmcli.active && Nmcli.active.ssid) {
            -                const stillConnected = Nmcli.active.ssid.toLowerCase().trim() === root.network.ssid.toLowerCase().trim();
            -                if (stillConnected) {
            -                    connectionMonitor.stop();
            -                    connectButton.connecting = false;
            -                    connectButton.text = qsTr("Connect");
            -                    // Return to network popout on successful connection
            -                    if (root.popouts.currentName === "wirelesspassword") {
            -                        root.popouts.currentName = "network";
            -                    }
            -                    closeDialog();
            -                }
            -            }
            -        }
            -    }
            -
            -    Connections {
            -        function onActiveChanged() {
            -            if (root.shouldBeVisible) {
            -                root.checkConnectionStatus();
            -            }
            -        }
            -
            -        function onConnectionFailed(ssid: string) {
            -            if (root.shouldBeVisible && root.network && root.network.ssid === ssid && connectButton.connecting) {
            -                connectionMonitor.stop();
            -                connectButton.connecting = false;
            -                connectButton.hasError = true;
            -                connectButton.enabled = true;
            -                connectButton.text = qsTr("Connect");
            -                passwordContainer.passwordBuffer = "";
            -                // Delete the failed connection
            -                Nmcli.forgetNetwork(ssid);
            -            }
            -        }
            -
            -        target: Nmcli
            -    }
             }
            diff --git a/modules/nexus/NexusState.qml b/modules/nexus/NexusState.qml
            --- a/modules/nexus/NexusState.qml
            +++ b/modules/nexus/NexusState.qml
            @@ -15,6 +15,7 @@ QtObject {
                 property DesktopEntry selectedApp
                 property int editingVpnIndex: -1
                 property string selectedNetworkSsid
            +    property var pendingNetwork: null
                 property string selectedEthernetInterface
                 property bool networkDetailsFromSaved

            @@ -32,5 +33,8 @@ QtObject {
                     subPageIdxStack.pop();
                 }

            -    onCurrentPageIdxChanged: subPageIdxStack.length = 0
            +    onCurrentPageIdxChanged: {
            +        subPageIdxStack.length = 0;
            +        pendingNetwork = null;
            +    }
             }
            diff --git a/modules/nexus/common/NetworkList.qml b/modules/nexus/common/NetworkList.qml
            --- a/modules/nexus/common/NetworkList.qml
            +++ b/modules/nexus/common/NetworkList.qml
            @@ -47,6 +47,7 @@ ItemList {
                     required property int index
                     required property var modelData
                     property bool currentSelected
            +        property string connectionError
                     property real textOpacity: disabled ? 0.5 : 1

                     disabled: currentSelected || Nmcli.connectingSsid() === modelData.ssid
            @@ -61,9 +62,17 @@ ItemList {

                     onClicked: {
                         if (!modelData.active) {
            -                NetworkConnection.handleConnect(modelData);
                             currentSelected = true;
            +                connectionError = "";
                             root.networkSelected(modelData);
            +                NetworkConnection.handleConnect(modelData, null, pending => {
            +                    root.nState.pendingNetwork = pending;
            +                    root.nState.openSubPage(2);
            +                }, result => {
            +                    currentSelected = false;
            +                    if (result && !result.success && !result.needsPassword)
            +                        connectionError = result.error || qsTr("Connection failed");
            +                });
                         } else {
                             // Active network: open its detail/settings sub-page.
                             root.nState.selectedNetworkSsid = modelData.ssid;
            @@ -126,15 +135,15 @@ ItemList {

                             StyledText {
                                 Layout.fillWidth: true
            -                    text: qsTr("Security: %1%2").arg(network.modelData.security).arg(network.modelData.active ? qsTr(" • Connected") : Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" • Saved") : "")
            -                    color: Colours.palette.m3outline
            +                    text: network.connectionError || qsTr("Security: %1%2").arg(network.modelData.security).arg(network.modelData.active ? qsTr(" • Connected") : Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" • Saved") : "")
            +                    color: network.connectionError ? Colours.palette.m3error : Colours.palette.m3outline
                                 font: Tokens.font.label.small
                                 elide: Text.ElideRight
                             }
                         }

                         AnimLoader {
            -                sourceComp: Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp
            +                sourceComp: network.currentSelected || Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp

                             Component {
                                 id: iconComp
            diff --git a/modules/nexus/pages/network/AddNetworkPage.qml b/modules/nexus/pages/network/AddNetworkPage.qml
            --- a/modules/nexus/pages/network/AddNetworkPage.qml
            +++ b/modules/nexus/pages/network/AddNetworkPage.qml
            @@ -6,6 +6,7 @@ import Caelestia.Config
             import qs.components
             import qs.components.controls
             import qs.services
            +import qs.utils
             import qs.modules.nexus.common

             // Sub-page for manually adding a (typically hidden) Wi-Fi network. Reached from
            @@ -14,7 +15,9 @@ PageBase {
                 id: root

                 // Security model: index 0 = none, 1 = WPA/WPA2/WPA3 personal.
            -    readonly property bool secured: securitySelect.active !== noneItem
            +    readonly property var visibleNetwork: root.nState.pendingNetwork
            +    readonly property bool visibleNetworkMode: !!visibleNetwork
            +    readonly property bool secured: visibleNetworkMode ? visibleNetwork.isSecure : securitySelect.active !== noneItem
                 property bool connecting: false
                 property bool failed: false
                 property bool success: false
            @@ -26,7 +29,7 @@ PageBase {
                         ssidField.forceActiveFocus();
                         return;
                     }
            -        if (root.secured && passwordField.text.length < 8) {
            +        if (root.secured && (root.visibleNetworkMode ? passwordField.text.length === 0 : passwordField.text.length < 8)) {
                         passwordField.isError = true;
                         passwordField.forceActiveFocus();
                         return;
            @@ -35,7 +38,7 @@ PageBase {
                     root.failed = false;
                     root.connecting = true;

            -        Nmcli.addHiddenNetwork(ssid, root.secured ? passwordField.text : "", root.secured ? "wpa" : "none", hiddenToggle.checked, result => {
            +        const callback = result => {
                         root.connecting = false;
                         if (result && result.success) {
                             root.success = true;
            @@ -44,13 +47,16 @@ PageBase {
                             root.failed = true;
                             if (root.secured)
                                 passwordField.isError = true;
            -                // Clean up the half-created profile so a retry starts fresh.
            -                Nmcli.forgetNetwork(ssid);
                         }
            -        });
            +        };
            +
            +        if (root.visibleNetworkMode)
            +            NetworkConnection.connectWithPassword(root.visibleNetwork, passwordField.text, callback);
            +        else
            +            Nmcli.addHiddenNetwork(ssid, root.secured ? passwordField.text : "", root.secured ? "wpa" : "none", hiddenToggle.checked, callback);
                 }

            -    title: qsTr("Add network")
            +    title: root.visibleNetworkMode ? qsTr("Connect to network") : qsTr("Add network")
                 isSubPage: true

                 ColumnLayout {
            @@ -61,12 +67,8 @@ PageBase {

                     Connections {
                         function onSubPageClosed(): void {
            -                if (root.success)
            -                    return;
            -
            -                const ssid = ssidField.text.trim();
            -                if (ssid)
            -                    Nmcli.forgetNetwork(ssid);
            +                root.connecting = false;
            +                root.nState.pendingNetwork = null;
                         }

                         target: root.nState
            @@ -75,7 +77,7 @@ PageBase {
                     StyledText {
                         Layout.fillWidth: true
                         Layout.leftMargin: Tokens.padding.extraSmall
            -            text: qsTr("Enter the details below to manually connect to a network.")
            +            text: root.visibleNetworkMode ? qsTr("Enter the password for this network.") : qsTr("Enter the details below to manually connect to a network.")
                         color: Colours.palette.m3onSurfaceVariant
                         font: Tokens.font.body.small
                         wrapMode: Text.WordWrap
            @@ -87,6 +89,8 @@ PageBase {
                         Layout.fillWidth: true
                         Layout.topMargin: Tokens.spacing.extraSmall
                         placeholderText: qsTr("Network name (SSID)")
            +            text: root.visibleNetworkMode ? root.visibleNetwork.ssid : ""
            +            enabled: !root.visibleNetworkMode
                         supportingText: qsTr("e.g. MyHiddenNetwork")
                         leadingIcon: "wifi"
                         errorText: qsTr("Network name is required")
            @@ -101,7 +105,8 @@ PageBase {
                         first: true
                         text: qsTr("Hidden network")
                         subtext: qsTr("Actively probe for a network that doesn't broadcast its name")
            -            checked: true
            +            checked: !root.visibleNetworkMode
            +            enabled: !root.visibleNetworkMode
                     }

                     SelectRow {
            @@ -110,8 +115,9 @@ PageBase {
                         Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                         last: !root.secured
                         label: qsTr("Security")
            -            fallbackText: qsTr("WPA/WPA2/WPA3 Personal")
            +            fallbackText: root.visibleNetworkMode ? root.visibleNetwork.security : qsTr("WPA/WPA2/WPA3 Personal")
                         fallbackIcon: "lock"
            +            enabled: !root.visibleNetworkMode

                         menuItems: [
                             MenuItem {
            @@ -173,8 +179,8 @@ PageBase {
                             placeholderText: qsTr("Password")
                             leadingIcon: "key"
                             echoMode: TextInput.Password
            -                supportingText: qsTr("WPA passwords are at least 8 characters")
            -                errorText: root.failed ? qsTr("Connection failed — check the password") : qsTr("Password must be at least 8 characters")
            +                supportingText: root.visibleNetworkMode ? qsTr("Security: %1").arg(root.visibleNetwork.security) : qsTr("WPA passwords are at least 8 characters")
            +                errorText: root.failed ? qsTr("Connection failed — check the password") : root.visibleNetworkMode ? qsTr("Password is required") : qsTr("Password must be at least 8 characters")

                             onAccepted: root.submit()
                         }
            diff --git a/services/Nmcli.qml b/services/Nmcli.qml
            --- a/services/Nmcli.qml
            +++ b/services/Nmcli.qml
            @@ -21,6 +21,7 @@ Singleton {
                 readonly property AccessPoint active: networks.find(n => n.active) ?? null
                 property list<string> savedConnections: []
                 property list<string> savedConnectionSsids: []
            +    property list<var> savedWifiProfiles: []
                 // Map of saved Wi-Fi SSID (lowercased) -> security type
                 property var savedConnectionSecurity: ({})

            @@ -52,7 +53,7 @@ Singleton {
                 readonly property string nmcliCommandWifi: "wifi"
                 readonly property string nmcliCommandRadio: "radio"
                 readonly property string deviceStatusFields: "DEVICE,TYPE,STATE,CONNECTION"
            -    readonly property string connectionListFields: "NAME,TYPE"
            +    readonly property string connectionListFields: "NAME,UUID,TYPE"
                 readonly property string wirelessSsidField: "802-11-wireless.ssid"
                 readonly property string networkListFields: "SSID,SIGNAL,SECURITY"
                 readonly property string networkDetailFields: "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY"
            @@ -400,49 +401,65 @@ Singleton {
                     connectWireless(ssid, password, bssid, callback);
                 }

            -    function connectWireless(ssid: string, password: string, bssid: string, callback: var, retryCount: int): void {
            -        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
            -        const retries = retryCount !== undefined ? retryCount : 0;
            -        const maxRetries = 2;
            -
            -        if (callback) {
            -            root.pendingConnection = {
            -                ssid: ssid,
            -                bssid: hasBssid ? bssid : "",
            -                callback: callback,
            -                retryCount: retries
            -            };
            -            connectionCheckTimer.start();
            -            immediateCheckTimer.checkCount = 0;
            -            immediateCheckTimer.start();
            +    function connectWireless(ssid: string, password: string, bssid: string, callback: var): void {
            +        let cmd = [root.nmcliCommandDevice, root.nmcliCommandWifi, "connect", ssid];
            +        if (password && password.length > 0) {
            +            cmd.push(root.connectionParamPassword, password);
                     }
            +        executeCommand(cmd, result => {
            +            if (result.success)
            +                loadSavedConnections(() => {});
            +            if (callback)
            +                callback(result);
            +        });
            +    }

            -        if (password && password.length > 0 && hasBssid) {
            -            const bssidUpper = bssid.toUpperCase();
            -            createConnectionWithPassword(ssid, bssidUpper, password, callback);
            +    function savedProfileFor(ssid: string): var {
            +        if (!ssid || ssid.length === 0)
            +            return null;
            +        const normalized = ssid.toLowerCase().trim();
            +        return root.savedWifiProfiles.find(profile => profile.ssid && profile.ssid.toLowerCase().trim() === normalized) ?? null;
            +    }
            +
            +    function activateSavedProfile(profileOrSsid: var, callback: var): void {
            +        const profile = typeof profileOrSsid === "string" ? savedProfileFor(profileOrSsid) : profileOrSsid;
            +        if (!profile || !profile.uuid) {
            +            if (callback)
            +                callback({
            +                    success: false,
            +                    output: "",
            +                    error: "Saved Wi-Fi profile not found",
            +                    exitCode: -1
            +                });
                         return;
                     }

            -        let cmd = [root.nmcliCommandDevice, root.nmcliCommandWifi, "connect", ssid];
            -        if (password && password.length > 0) {
            -            cmd.push(root.connectionParamPassword, password);
            +        executeCommand([root.nmcliCommandConnection, "up", "uuid", profile.uuid], result => {
            +            if (callback)
            +                callback(result);
            +        });
            +    }
            +
            +    function connectSavedWithPassword(profileOrSsid: var, password: string, callback: var): void {
            +        const profile = typeof profileOrSsid === "string" ? savedProfileFor(profileOrSsid) : profileOrSsid;
            +        if (!profile || !profile.uuid) {
            +            if (callback)
            +                callback({
            +                    success: false,
            +                    output: "",
            +                    error: "Saved Wi-Fi profile not found",
            +                    exitCode: -1
            +                });
            +            return;
                     }
            -        executeCommand(cmd, result => {
            -            if (result.needsPassword && callback) {
            -                if (callback)
            -                    callback(result);
            -                return;
            -            }

            -            if (!result.success && root.pendingConnection && retries < maxRetries) {
            -                console.warn(lc, "Connection failed, retrying... (attempt " + (retries + 1) + "/" + maxRetries + ")");
            -                Qt.callLater(() => {
            -                    connectWireless(ssid, password, bssid, callback, retries + 1);
            -                }, 1000);
            -            } else if (!result.success && root.pendingConnection) {} else if (result.success && callback) {} else if (!result.success && !root.pendingConnection) {
            +        executeCommand([root.nmcliCommandConnection, "modify", "uuid", profile.uuid, root.securityPsk, password, "802-11-wireless-security.psk-flags", "0"], result => {
            +            if (!result.success) {
                             if (callback)
                                 callback(result);
            +                return;
                         }
            +            activateSavedProfile(profile, callback);
                     });
                 }

            @@ -501,6 +518,7 @@ Singleton {
                         if (!result.success) {
                             root.savedConnections = [];
                             root.savedConnectionSsids = [];
            +                root.savedWifiProfiles = [];
                             root.savedConnectionSecurity = {};
                             if (callback)
                                 callback([]);
            @@ -517,14 +535,18 @@ Singleton {
                     const connections = [];

                     for (const line of lines) {
            -            const parts = line.split(":");
            -            if (parts.length >= 2) {
            +            const parts = line.replace(/\\:/g, "\u0000").split(":").map(part => part.replace(/\u0000/g, ":"));
            +            if (parts.length >= 3) {
                             const name = parts[0];
            -                const type = parts[1];
            +                const uuid = parts[1];
            +                const type = parts[2];
                             connections.push(name);

                             if (type === root.connectionTypeWireless) {
            -                    wifiConnections.push(name);
            +                    wifiConnections.push({
            +                        id: name,
            +                        uuid: uuid
            +                    });
                             }
                         }
                     }
            @@ -532,6 +554,7 @@ Singleton {
                     root.savedConnections = connections;

                     root.savedConnectionSecurity = {};
            +        root.savedWifiProfiles = [];

                     if (wifiConnections.length > 0) {
                         root.wifiConnectionQueue = wifiConnections;
            @@ -548,12 +571,12 @@ Singleton {

                 function queryNextSsid(callback: var): void {
                     if (root.currentSsidQueryIndex < root.wifiConnectionQueue.length) {
            -            const connectionName = root.wifiConnectionQueue[root.currentSsidQueryIndex];
            +            const connection = root.wifiConnectionQueue[root.currentSsidQueryIndex];
                         root.currentSsidQueryIndex++;

            -            executeCommand(["-t", "-f", `''${root.wirelessSsidField},''${root.securityKeyMgmt}`, root.nmcliCommandConnection, "show", connectionName], result => {
            +            executeCommand(["-t", "-f", `''${root.wirelessSsidField},''${root.securityKeyMgmt}`, root.nmcliCommandConnection, "show", "uuid", connection.uuid], result => {
                             if (result.success) {
            -                    processSsidOutput(result.output);
            +                    processSsidOutput(result.output, connection);
                             }
                             queryNextSsid(callback);
                         });
            @@ -565,7 +588,7 @@ Singleton {
                     }
                 }

            -    function processSsidOutput(output: string): void {
            +    function processSsidOutput(output: string, connection: var): void {
                     const ssidPrefix = "802-11-wireless.ssid:";
                     const keyMgmtPrefix = `''${root.securityKeyMgmt}:`;

            @@ -583,6 +606,15 @@ Singleton {

                     const ssidLower = ssid.toLowerCase();

            +        const profiles = root.savedWifiProfiles.slice();
            +        profiles.push({
            +            id: connection.id,
            +            uuid: connection.uuid,
            +            ssid: ssid,
            +            keyMgmt: keyMgmt
            +        });
            +        root.savedWifiProfiles = profiles;
            +
                     const exists = root.savedConnectionSsids.some(s => s && s.toLowerCase() === ssidLower);
                     if (!exists) {
                         const newList = root.savedConnectionSsids.slice();
            @@ -629,6 +661,9 @@ Singleton {
                     }
                     const ssidLower = ssid.toLowerCase().trim();

            +        if (savedProfileFor(ssid))
            +            return true;
            +
                     if (root.active && root.active.ssid) {
                         const activeSsidLower = root.active.ssid.toLowerCase().trim();
                         if (activeSsidLower === ssidLower) {
            @@ -762,9 +797,10 @@ Singleton {
                         return;
                     }

            -        const connectionName = root.savedConnections.find(conn => conn && conn.toLowerCase().trim() === ssid.toLowerCase().trim()) || ssid;
            +        const profile = savedProfileFor(ssid);
            +        const connectionRef = profile ? ["uuid", profile.uuid] : [root.savedConnections.find(conn => conn && conn.toLowerCase().trim() === ssid.toLowerCase().trim()) || ssid];

            -        executeCommand([root.nmcliCommandConnection, "delete", connectionName], result => {
            +        executeCommand([root.nmcliCommandConnection, "delete", ...connectionRef], result => {
                         if (result.success) {
                             Qt.callLater(() => {
                                 loadSavedConnections(() => {});
            diff --git a/utils/NetworkConnection.qml b/utils/NetworkConnection.qml
            --- a/utils/NetworkConnection.qml
            +++ b/utils/NetworkConnection.qml
            @@ -29,27 +29,16 @@ QtObject {
                 id: root

                 /**
            -     * Handle network connection with automatic disconnection if needed.
            -     * If there's an active network different from the target, disconnects first,
            -     * then connects to the target network.
            +     * Connect without taking the active network down first. NetworkManager keeps
            +     * it available until the replacement connection has actually succeeded.
                  *
                  * @param network The network object to connect to (must have ssid property)
            -     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
            -     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
            +     * @param session Optional legacy Session object
            +     * @param onPasswordNeeded Optional callback function(network)
            +     * @param onResult Optional callback function(result)
                  */
            -    function handleConnect(network, session, onPasswordNeeded): void {
            -        if (!network) {
            -            return;
            -        }
            -
            -        if (Nmcli.active && Nmcli.active.ssid !== network.ssid) {
            -            Nmcli.disconnectFromNetwork();
            -            Qt.callLater(() => {
            -                root.connectToNetwork(network, session, onPasswordNeeded);
            -            });
            -        } else {
            -            root.connectToNetwork(network, session, onPasswordNeeded);
            -        }
            +    function handleConnect(network, session, onPasswordNeeded, onResult): void {
            +        root.connectToNetwork(network, session, onPasswordNeeded, onResult);
                 }

                 /**
            @@ -61,41 +50,66 @@ QtObject {
                  * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
                  * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
                  */
            -    function connectToNetwork(network, session, onPasswordNeeded): void {
            +    function connectToNetwork(network, session, onPasswordNeeded, onResult): void {
                     if (!network) {
            +            if (onResult)
            +                onResult({
            +                    success: false,
            +                    output: "",
            +                    error: "No network specified",
            +                    exitCode: -1
            +                });
                         return;
                     }

            -        if (network.isSecure) {
            -            const hasSavedProfile = Nmcli.hasSavedProfile(network.ssid);
            -
            -            if (hasSavedProfile) {
            -                Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
            -            } else {
            -                // Use password check with callback
            -                Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
            -                    if (result.needsPassword) {
            -                        // Clear pending connection if exists
            -                        if (Nmcli.pendingConnection) {
            -                            Nmcli.connectionCheckTimer.stop();
            -                            Nmcli.immediateCheckTimer.stop();
            -                            Nmcli.immediateCheckTimer.checkCount = 0;
            -                            Nmcli.pendingConnection = null;
            -                        }
            +        if (network.active) {
            +            if (onResult)
            +                onResult({
            +                    success: true,
            +                    output: "Already connected",
            +                    error: "",
            +                    exitCode: 0
            +                });
            +            return;
            +        }

            -                        // Handle password dialog - use session if available, otherwise use callback
            -                        if (session && session.network) {
            -                            session.network.showPasswordDialog = true;
            -                            session.network.pendingNetwork = network;
            -                        } else if (onPasswordNeeded) {
            -                            onPasswordNeeded(network);
            -                        }
            +        const profile = Nmcli.savedProfileFor(network.ssid);
            +        if (profile) {
            +            Nmcli.activateSavedProfile(profile, result => {
            +                if (result.needsPassword) {
            +                    if (session && session.network) {
            +                        session.network.showPasswordDialog = true;
            +                        session.network.pendingNetwork = network;
            +                    } else if (onPasswordNeeded) {
            +                        onPasswordNeeded(network);
                                 }
            -                }, network.bssid);
            -            }
            -        } else {
            -            Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
            +                }
            +                if (onResult)
            +                    onResult(result);
            +            });
            +            return;
            +        }
            +
            +        if (!network.isSecure) {
            +            Nmcli.connectWireless(network.ssid, "", "", onResult || null);
            +            return;
                     }
            +
            +        if (session && session.network) {
            +            session.network.showPasswordDialog = true;
            +            session.network.pendingNetwork = network;
            +        } else if (onPasswordNeeded) {
            +            onPasswordNeeded(network);
            +        }
            +
            +        if (onResult)
            +            onResult({
            +                success: false,
            +                needsPassword: true,
            +                output: "",
            +                error: "Password required",
            +                exitCode: -1
            +            });
                 }

                 /**
            @@ -108,9 +122,21 @@ QtObject {
                  */
                 function connectWithPassword(network, password, onResult): void {
                     if (!network) {
            +            if (onResult)
            +                onResult({
            +                    success: false,
            +                    output: "",
            +                    error: "No network specified",
            +                    exitCode: -1
            +                });
                         return;
                     }

            -        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", onResult || null);
            +        const profile = Nmcli.savedProfileFor(network.ssid);
            +        if (profile) {
            +            Nmcli.connectSavedWithPassword(profile, password || "", onResult || null);
            +        } else {
            +            Nmcli.connectWireless(network.ssid, password || "", "", onResult || null);
            +        }
                 }
             }
          '')
        ];
      });
in
{
  # Sobreescribe tanto el binario del shell (para que execDetached del panel
  # use nuestro wrapper) como el paquete de la CLI que se instala aparte en
  # home.packages (terminal, Hyprland) — ver modules/home/caelestia.nix.
  programs.caelestia.package = wrappedShell;
  programs.caelestia.cli.package = wrappedCli;
}
