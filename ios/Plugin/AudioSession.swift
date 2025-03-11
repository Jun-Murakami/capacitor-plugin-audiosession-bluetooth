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
            // 遅延後に実行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.switchToOptimalOutput()
            }
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
                try session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP,.allowAirPlay,.mixWithOthers])
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
                return AudioSessionPorts.first { $0.value == portString }?.key
            }
        }
        
        if self.autoSwitchBluetooth {
            let session = AVAudioSession.sharedInstance()
            do {
                // 現在の出力デバイスをログ出力
                let currentOutputs = session.currentRoute.outputs
                    .compactMap { AudioSessionPorts[$0.portType] }
                    .joined(separator: ", ")
                CAPLog.print("現在の出力デバイス: [\(currentOutputs)]")

                try session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP, .allowAirPlay, .mixWithOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                
                // 遅延後に優先デバイスチェック
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.forceUpdateAudioRoute()
                }
            } catch {
                CAPLog.print("AudioSession configure error: \(error.localizedDescription)")
            }
        }
    }

    private func forceUpdateAudioRoute() {
        let session = AVAudioSession.sharedInstance()
        do {
            let currentOutputs = session.currentRoute.outputs
                .compactMap { AudioSessionPorts[$0.portType] }
                .joined(separator: ", ")
            CAPLog.print("更新前の出力デバイス: [\(currentOutputs)]")
            
            self.switchToOptimalOutput()
            
            let newOutputs = session.currentRoute.outputs
                .compactMap { AudioSessionPorts[$0.portType] }
                .joined(separator: ", ")
            CAPLog.print("更新後の出力デバイス: [\(newOutputs)]")
            
        } catch {
            CAPLog.print("Force update audio route failed: \(error.localizedDescription)")
        }
    }

    private func switchToOptimalOutput() {
        CAPLog.print("switchToOptimalOutput() start")
        let session = AVAudioSession.sharedInstance()
        let currentOutputs = session.currentRoute.outputs
        
        // 全ての利用可能な出力デバイスを列挙
        let availableInputs = AVAudioSession.sharedInstance().availableInputs ?? []
        CAPLog.print("システムで検出された全ての入力デバイス:")
        availableInputs.forEach { portDesc in
            let portType = portDesc.portType
            let portName = AudioSessionPorts[portType] ?? "unknown"
            CAPLog.print("- \(portName)(\(portType.rawValue))")
            CAPLog.print("  データソース一覧: \(portDesc.dataSources?.map { $0.dataSourceName } ?? [])")
        }
        
        // 現在接続中のルート詳細表示
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        CAPLog.print("現在のオーディオルート詳細:")
        currentRoute.outputs.forEach { portDesc in
            let portType = portDesc.portType
            let portName = AudioSessionPorts[portType] ?? "unknown"
            CAPLog.print("- 出力: \(portName)(\(portType.rawValue))")
            CAPLog.print("  選択データソース: \(portDesc.selectedDataSource?.dataSourceName ?? "none")")
            CAPLog.print("  推奨データソース: \(portDesc.preferredDataSource?.dataSourceName ?? "none")")
        }
        
        // 優先順位リストをログ出力
        let priorityList = priorityOrder.compactMap { AudioSessionPorts[$0] }.joined(separator: ", ")
        CAPLog.print("優先順位リスト: [\(priorityList)]")
        
        // 現在の出力デバイスの詳細をログ出力（生の値も含む）
        let currentOutputDetails = currentOutputs.map {
            "\(AudioSessionPorts[$0.portType] ?? "unknown")(\($0.portType.rawValue))"
        }.joined(separator: ", ")
        CAPLog.print("現在の出力デバイス: [\(currentOutputDetails)]")
        
        // 優先順位に従って切り替え
        for priority in self.priorityOrder {
            CAPLog.print("チェック中の優先デバイス: \(AudioSessionPorts[priority] ?? "unknown")")
            if let _ = currentOutputs.first(where: { $0.portType == priority }) {
                do {
                    CAPLog.print("\(AudioSessionPorts[priority] ?? "unknown") に切り替えを試みます")
                    // スピーカーへの切り替え条件を厳密化
                    if priority == .builtInSpeaker {
                        // 他の優先デバイスが全て接続されていない場合のみスピーカーを使用
                        let hasHigherPriority = priorityOrder[0..<(priorityOrder.firstIndex(of: .builtInSpeaker) ?? 0)]
                            .contains { port in
                                currentOutputs.contains { $0.portType == port }
                            }
                        
                        if !hasHigherPriority {
                            try session.overrideOutputAudioPort(.speaker)
                        }
                    } else {
                        try session.overrideOutputAudioPort(.none)
                    }
                    try session.setActive(true)
                    CAPLog.print("\(AudioSessionPorts[priority] ?? "unknown") への切り替え成功")
                    break
                } catch {
                    CAPLog.print("\(AudioSessionPorts[priority] ?? "unknown") への切り替え失敗: \(error.localizedDescription)")
                }
            } else {
                CAPLog.print("\(AudioSessionPorts[priority] ?? "unknown") は接続されていません")
            }
        }
    }
}
