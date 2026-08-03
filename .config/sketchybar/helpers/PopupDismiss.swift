import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3 else {
    exit(EXIT_FAILURE)
}

let popup = CommandLine.arguments[1]
let pidFile = CommandLine.arguments[2]

func closePopup() -> Never {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["sketchybar", "--set", popup, "popup.drawing=off"]
    try? process.run()
    process.waitUntilExit()
    try? FileManager.default.removeItem(atPath: pidFile)
    exit(EXIT_SUCCESS)
}

func mouseButtonIsPressed() -> Bool {
    CGEventSource.buttonState(.combinedSessionState, button: .left)
        || CGEventSource.buttonState(.combinedSessionState, button: .right)
        || CGEventSource.buttonState(.combinedSessionState, button: .center)
}

while mouseButtonIsPressed() {
    usleep(25_000)
}

while true {
    if mouseButtonIsPressed() {
        closePopup()
    }
    usleep(25_000)
}
