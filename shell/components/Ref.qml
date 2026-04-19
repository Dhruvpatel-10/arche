import QtQuick

// Ref — lightweight service activator. Mount one inside any consumer
// that reads from a ref-counted service:
//
//   Ref { service: SystemStats }
//
// While this object is alive, `service.refCount` stays incremented. On
// destroy it decrements automatically (Component.onDestruction). Services
// whose Timers bind `running: refCount > 0` go idle whenever no consumer
// is mounted.
//
// Pattern from /tmp/shell components/misc/Ref.qml. Keeps polling cheap
// without forcing every consumer to manually wire start/stop logic.
QtObject {
    id: root
    required property var service

    Component.onCompleted: {
        if (root.service && typeof root.service.refCount === "number")
            root.service.refCount = root.service.refCount + 1
    }
    Component.onDestruction: {
        if (root.service && typeof root.service.refCount === "number")
            root.service.refCount = root.service.refCount - 1
    }
}
