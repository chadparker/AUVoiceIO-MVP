import UIKit
import AVFoundation.AVFAudio

private extension String {
    static let record = "Record"
    static let play = "Play"
    static let stop = "Stop"
    static let micMode = "Mic Mode"
}

class ViewController: UIViewController {

    // MARK: - Views

    private lazy var recordButton = UIButton(type: .system).configure {
        $0.setTitle(.record, for: .normal)
        $0.addTarget(self, action: #selector(recordPressed), for: .touchUpInside)
    }

    private lazy var playButton = UIButton(type: .system).configure {
        $0.setTitle(.play, for: .normal)
        $0.addTarget(self, action: #selector(playPressed), for: .touchUpInside)
    }

    private lazy var micModeButton = UIButton(type: .system).configure {
        $0.setTitle(.micMode, for: .normal)
        $0.addTarget(self, action: #selector(micModePressed), for: .touchUpInside)
    }

    // MARK: - Properties

    private var audioEngine: AudioEngine!

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
        setUpAudioEngine()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleMediaServicesWereReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    // MARK: - Actions

    @objc func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Interruption began, take appropriate actions

            if let isRecording = audioEngine?.isRecording, isRecording {
                recordButton.setTitle(.record, for: .normal)
            }
            audioEngine?.stopRecordingAndPlayers()

            playButton.setTitle(.play, for: .normal)
            playButton.isEnabled = false
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Could not set audio session active: \(error)")
            }

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption Ended - playback should resume
                } else {
                    // Interruption Ended - playback should NOT resume
                }
            }
        @unknown default:
            fatalError("Unknown type: \(type)")
        }
    }

    @objc func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
            let routeDescription = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
        switch reason {
        case .newDeviceAvailable:
            print("newDeviceAvailable")
        case .oldDeviceUnavailable:
            print("oldDeviceUnavailable")
        case .categoryChange:
            print("categoryChange")
            print("New category: \(AVAudioSession.sharedInstance().category)")
        case .override:
            print("override")
        case .wakeFromSleep:
            print("wakeFromSleep")
        case .noSuitableRouteForCategory:
            print("noSuitableRouteForCategory")
        case .routeConfigurationChange:
            print("routeConfigurationChange")
        case .unknown:
            print("unknown")
        @unknown default:
            fatalError("Really unknown reason: \(reason)")
        }

        print("Previous route:\n\(routeDescription)")
        print("Current route:\n\(AVAudioSession.sharedInstance().currentRoute)")
    }

    @objc func handleMediaServicesWereReset(_ notification: Notification) {
        resetUIStates()
        audioEngine = nil
        setUpAudioEngine()
    }

    @objc func recordPressed(_ sender: UIButton) {
        print("Record button pressed.")
        audioEngine?.checkEngineIsRunning()
        audioEngine?.toggleRecording()

        if let isRecording = audioEngine?.isRecording, isRecording {
            sender.setTitle(.stop, for: .normal)
            playButton.isEnabled = false
        } else {
            sender.setTitle(.record, for: .normal)
            playButton.isEnabled = true
        }
    }

    @objc func playPressed(_ sender: UIButton) {
        print("Play button pressed.")
        audioEngine?.checkEngineIsRunning()
        audioEngine?.togglePlaying()

        if let isPlaying = audioEngine?.isPlaying, isPlaying {
            playButton.setTitle(.stop, for: .normal)
            recordButton.isEnabled = false
        } else {
            playButton.setTitle(.play, for: .normal)
            recordButton.isEnabled = true
        }
    }

    @objc func micModePressed(_ sender: UIButton) {
        AVCaptureDevice.showSystemUserInterface(.microphoneModes)
    }

    // MARK: - Methods

    private func setUpViews() {
        let stackView = UIStackView(arrangedSubviews: [recordButton, playButton, micModeButton]).configure {
            $0.distribution = .fillEqually
        }
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setUpAudioEngine() {
        do {
            audioEngine = try AudioEngine()

            setupAudioSession(sampleRate: audioEngine.voiceIOFormat.sampleRate)

            audioEngine.setup()
            audioEngine.start()
        } catch {
            fatalError("Could not set up audio engine: \(error)")
        }
    }

    private func setupAudioSession(sampleRate: Double) {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        } catch {
            print("Could not set audio category: \(error.localizedDescription)")
        }

        do {
            try session.setPreferredSampleRate(sampleRate)
        } catch {
            print("Could not set preferred sample rate: \(error.localizedDescription)")
        }
    }

    func resetUIStates() {
        recordButton.setTitle(.record, for: .normal)
        recordButton.isEnabled = true
        playButton.setTitle(.play, for: .normal)
        playButton.isEnabled = false
    }
}
