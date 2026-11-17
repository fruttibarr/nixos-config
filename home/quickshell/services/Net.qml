pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Thin view over Quickshell.Networking (NetworkManager backend).
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wiredUp: wiredDevice?.connected ?? false
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property real strength: wifiNetwork?.signalStrength ?? 0

    readonly property string icon: {
        if (wiredUp && !wifiNetwork) return "󰈀";
        if (!wifiOn) return "󰤮";
        if (!wifiNetwork) return "󰤯";
        if (strength > 0.75) return "󰤨";
        if (strength > 0.5) return "󰤥";
        if (strength > 0.25) return "󰤢";
        return "󰤟";
    }

    readonly property string label: {
        if (wifiNetwork) return wifiNetwork.name;
        if (wiredUp) return "Ethernet";
        if (!wifiOn) return "Off";
        return "Not connected";
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
