import AVFoundation

final class MorseTonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var activeSenders = Set<String>()

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func keyDown(from sender: String) {
        let wasSilent = activeSenders.isEmpty
        activeSenders.insert(sender)
        guard wasSilent else { return }

        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            player.scheduleBuffer(makeToneBuffer(), at: nil, options: .loops)
            player.play()
        } catch {
            NSLog("Morse Radio audio could not start: %@", error.localizedDescription)
        }
    }

    func keyUp(from sender: String) {
        activeSenders.remove(sender)
        if activeSenders.isEmpty {
            player.stop()
        }
    }

    func releaseAll() {
        activeSenders.removeAll()
        player.stop()
    }

    private func makeToneBuffer() -> AVAudioPCMBuffer {
        let frameCount: AVAudioFrameCount = 4_410
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        let rate = format.sampleRate
        for frame in 0..<Int(frameCount) {
            let phase = 2.0 * Double.pi * 650.0 * Double(frame) / rate
            samples[frame] = Float(sin(phase) * 0.16)
        }
        return buffer
    }
}
