import AVFoundation
import Foundation

class AudioEngine {

    // MARK: - Properties

    private var recordedFileURL = URL(
        fileURLWithPath: "input.caf",
        isDirectory: false,
        relativeTo: URL(fileURLWithPath: NSTemporaryDirectory())
    )
    private var recordedFilePlayer = AVAudioPlayerNode()
    private var avAudioEngine = AVAudioEngine()
    private var isNewRecordingAvailable = false
    private var fileFormat: AVAudioFormat
    private var recordedFile: AVAudioFile?

    public private(set) var voiceIOFormat: AVAudioFormat
    public private(set) var isRecording = false

    enum AudioEngineError: Error {
        case bufferRetrieveError
        case fileFormatError
        case audioFileNotFound
    }

    init() throws {
        avAudioEngine.attach(recordedFilePlayer)

        guard
            let tempFileFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioEngineError.fileFormatError
        }
        fileFormat = tempFileFormat
        voiceIOFormat = tempFileFormat
        print("File format: \(String(describing: fileFormat))")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged(_:)),
            name: .AVAudioEngineConfigurationChange,
            object: avAudioEngine
        )
    }

    @objc func configChanged(_ notification: Notification) {
        checkEngineIsRunning()
    }

    private static func getBuffer(fileURL: URL) -> AVAudioPCMBuffer? {
        let file: AVAudioFile!
        do {
            try file = AVAudioFile(forReading: fileURL)
        } catch {
            print("Could not load file: \(error)")
            return nil
        }
        file.framePosition = 0
        let bufferCapacity = AVAudioFrameCount(file.length)
                + AVAudioFrameCount(file.processingFormat.sampleRate * 0.1) // add 100ms to capacity
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: bufferCapacity) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            print("Could not load file into buffer: \(error)")
            return nil
        }
        file.framePosition = 0
        return buffer
    }

    func setup() {
        let input = avAudioEngine.inputNode
        do {
            try input.setVoiceProcessingEnabled(true)
        } catch {
            print("Could not enable voice processing \(error)")
            return
        }

        let output = avAudioEngine.outputNode
        let mainMixer = avAudioEngine.mainMixerNode

        avAudioEngine.connect(recordedFilePlayer, to: mainMixer, format: voiceIOFormat)
        avAudioEngine.connect(mainMixer, to: output, format: voiceIOFormat)

        input.installTap(onBus: 0, bufferSize: 256, format: voiceIOFormat) { buffer, when in
            if self.isRecording {
                do {
                    try self.recordedFile?.write(from: buffer)
                } catch {
                    print("Could not write buffer: \(error)")
                }
                //self.voiceIOPowerMeter.process(buffer: buffer)
            } else {
                //self.voiceIOPowerMeter.processSilence()
            }
        }
        avAudioEngine.prepare()
    }

    func start() {
        do {
            try avAudioEngine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }

    func checkEngineIsRunning() {
        if !avAudioEngine.isRunning {
            start()
        }
    }

    func toggleRecording() {
        if isRecording {
            isRecording = false
            recordedFile = nil // close file
        } else {
            recordedFilePlayer.stop()

            do {
                recordedFile = try AVAudioFile(forWriting: recordedFileURL, settings: fileFormat.settings)
                isNewRecordingAvailable = true
                isRecording = true
            } catch {
                print("Could not create file for recording: \(error)")
            }
        }
    }

    func stopRecordingAndPlayers() {
        if isRecording {
            isRecording = false
        }

        recordedFilePlayer.stop()
    }

    var isPlaying: Bool {
        return recordedFilePlayer.isPlaying
    }

    func togglePlaying() {
        if recordedFilePlayer.isPlaying {
            recordedFilePlayer.pause()
        } else {
            if isNewRecordingAvailable {
                guard let recordedBuffer = AudioEngine.getBuffer(fileURL: recordedFileURL) else { return }
                recordedFilePlayer.scheduleBuffer(recordedBuffer, at: nil, options: .loops)
                isNewRecordingAvailable = false
            }
            recordedFilePlayer.play()
        }
    }
}
