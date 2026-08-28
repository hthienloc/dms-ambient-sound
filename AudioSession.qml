import QtQuick
import Quickshell.Io

Item {
    id: root

    required property string sessionId
    required property string backend
    required property string sourcePath
    required property string socketPath
    required property real effectiveVolume

    readonly property bool running: player.running
    property bool stopping: false
    property bool restartPending: false
    property bool processActive: false

    signal volumeCommandRequested(string socketPath, real volume)
    signal finished(int exitCode)

    function start() {
        stopping = false;
        processActive = true;
        player.running = true;
    }

    function applyVolume(volume) {
        effectiveVolume = volume;
        if (backend === "mpv") {
            volumeCommandRequested(socketPath, volume);
            return;
        }

        // ffplay has no IPC API, so restart only this owned process to apply volume/mute.
        restartPending = true;
        if (processActive) {
            player.running = false;
        } else {
            restartPending = false;
            restartTimer.restart();
        }
    }

    function stop() {
        stopping = true;
        restartPending = false;
        restartTimer.stop();
        if (processActive) {
            player.running = false;
        } else {
            finished(0);
        }
    }

    Process {
        id: player
        running: false
        command: root.backend === "mpv"
            ? [
                "mpv",
                "--no-video",
                "--no-config",
                "--loop=inf",
                "--volume=" + root.effectiveVolume,
                "--input-ipc-server=" + root.socketPath,
                root.sourcePath
            ]
            : [
                "ffplay",
                "-nodisp",
                "-loglevel", "quiet",
                "-loop", "0",
                "-volume", String(Math.round(root.effectiveVolume)),
                root.sourcePath
            ]

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.processActive = false;
            if (root.restartPending && !root.stopping) {
                root.restartPending = false;
                restartTimer.restart();
                return;
            }
            root.finished(exitCode);
        }
    }

    Timer {
        id: restartTimer
        interval: 25
        onTriggered: {
            if (!root.stopping) {
                root.processActive = true;
                player.running = true;
            }
        }
    }
}
