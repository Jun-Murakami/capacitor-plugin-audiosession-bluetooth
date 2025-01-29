import Foundation
import Capacitor
import AVKit

var AudioSessionOverrideTypes: [AVAudioSession.PortOverride: String] = [
    .none: "none",
    .speaker: "speaker"
]

var AudioSessionRouteChangeReasons: [AVAudioSession.RouteChangeReason: String] = [
    .newDeviceAvailable: "new-device-available",
    .oldDeviceUnavailable: "old-device-unavailable",
    .categoryChange: "category-change",
    .override: "override",
    .wakeFromSleep: "wake-from-sleep",
    .noSuitableRouteForCategory: "no-suitable-route-for-category",
    .routeConfigurationChange: "route-config-change",
    .unknown: "unknown"
]

var AudioSessionInterruptionTypes: [AVAudioSession.InterruptionType: String] = [
    .began: "began",
    .ended: "ended"
]

var AudioSessionPorts: [AVAudioSession.Port: String] = [
    .airPlay: "airplay",
    .bluetoothLE: "bluetooth-le",
    .bluetoothHFP: "bluetooth-hfp",
    .bluetoothA2DP: "bluetooth-a2dp",
    .builtInSpeaker: "builtin-speaker",
    .builtInReceiver: "builtin-receiver",
    .HDMI: "hdmi",
    .headphones: "headphones",
    .lineOut: "line-out"
]

public typealias AudioSessionRouteChangeObserver = (String) -> Void
public typealias AudioSessionInterruptionObserver = (String) -> Void
public typealias AudioSessionOverrideCallback = (Bool, String?, Bool?) -> Void

public class AudioSession: NSObject {

    var routeChangeObserver: AudioSessionRouteChangeObserver?
    var interruptionObserver: AudioSessionInterruptionObserver?

    var currentOverride: String?

    private var autoSwitchBluetooth: Bool = false
    private var priorityOrder: [AVAudioSession.Port] = [
        .lineOut,
        .headphones,
        .bluetoothA2DP,
        .bluetoothHFP,
        .builtInSpeaker
    ]

    public func load() {
        let nc = NotificationCenter.default

        nc.addObserver(self,
                       selector: #selector(self.handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(self.handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance)
    }

    // EVENTS

    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reasonType = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        let readableReason = AudioSessionRouteChangeReasons[reasonType] ?? "unknown"

        CAPLog.print("AudioSession.handleRouteChange() changed to \(readableReason)")

        // 自動切り替えが有効な場合、最適な出力に切り替え
        if self.autoSwitchBluetooth {
            self.switchToOptimalOutput()
        }

        self.routeChangeObserver?(readableReason)
    }

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptType = AVAudioSession.InterruptionType(rawValue: interruptValue) else { return }
        let readableInterrupt = AudioSessionInterruptionTypes[interruptType] ?? "unknown"

        CAPLog.print("AudioSession.handleInterruption() interrupted status to \(readableInterrupt)")

        self.interruptionObserver?(readableInterrupt)
    }

    // METHODS

    public func currentOutputs() -> [String?] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map({AudioSessionPorts[$0.portType]})

        return outputs
    }

    public func overrideOutput(_output: String, _callback: @escaping AudioSessionOverrideCallback) {
        if _output == "unknown" {
            return _callback(false, "No valid output provided...", nil)
        }

        if self.currentOverride == _output {
            return _callback(true, nil, nil)
        }

        // make it async, cause in latest IOS it started to take ~1 sec and produce UI thread blocking issues
        DispatchQueue.global(qos: .utility).async {
            let session = AVAudioSession.sharedInstance()

            // make sure the AVAudioSession is properly configured
            do {
                try session.setActive(true)
                try session.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.duckOthers)
            } catch {
                CAPLog.print("AudioSession.overrideOutput() error setting sessions settings.")
                _callback(false, "Error setting sessions settings.", true)
                return
            }

            do {
                if _output == "speaker" {
                    try session.overrideOutputAudioPort(.speaker)
                } else {
                    try session.overrideOutputAudioPort(.none)
                }

                self.currentOverride = _output

                CAPLog.print("currentOverride: " + (self.currentOverride ?? "") + " - " + _output)

                _callback(true, nil, nil)
            } catch {
                CAPLog.print("AudioSession.overrideOutput() could not override output port.")
                _callback(false, "Could not override output port.", true)
            }
        }
    }

    public func configure(options: [String: Any]) {
        if let autoSwitch = options["autoSwitchBluetooth"] as? Bool {
            self.autoSwitchBluetooth = autoSwitch
        }
        
        if let priorities = options["priorityOrder"] as? [String] {
            self.priorityOrder = priorities.compactMap { portString in
                // AudioSessionPortsの文字列からAVAudioSession.Portに変換
                return AudioSessionPorts.first { $0.value == portString }?.key
            }
        }
        
        // 現在の接続状態をチェックして必要なら切り替え
        if self.autoSwitchBluetooth {
            self.switchToOptimalOutput()
        }
    }

    private func switchToOptimalOutput() {
        let session = AVAudioSession.sharedInstance()
        let currentOutputs = session.currentRoute.outputs
        
        // 優先順位に従って最適な出力を探す
        for priority in self.priorityOrder {
            if let _ = currentOutputs.first(where: { $0.portType == priority }) {
                // この出力が利用可能な場合、切り替え
                do {
                    if priority == .builtInSpeaker {
                        try session.overrideOutputAudioPort(.speaker)
                    } else {
                        try session.overrideOutputAudioPort(.none)
                    }
                    break
                } catch {
                    CAPLog.print("AudioSession.switchToOptimalOutput() could not override to \(priority)")
                }
            }
        }
    }
}
