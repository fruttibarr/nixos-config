pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Laptop battery via UPower (services.upower must be enabled).
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: (dev?.ready ?? false) && (dev?.isLaptopBattery ?? false)

    // UPower has reported this as both 0-1 and 0-100 across versions.
    readonly property real fraction: {
        const p = dev?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
        || dev?.state === UPowerDeviceState.FullyCharged
        || dev?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: present && !charging && percent <= 20

    readonly property string icon: {
        if (charging) return "󰂄";
        const steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(10, Math.round(fraction * 10)))];
    }
}
