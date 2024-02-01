//
//  ViewController+Recorder.swift
//  assignment
//
//  Created by cz on 2024/2/1.
//

import Foundation
import AVFoundation

extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        clearCurrentPlay()
    }
}

extension ViewController {
    func setupAudioRecorder() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        currentDateString = dateFormatter.string(from: Date())
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(currentDateString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        } catch {
            print("Error setting up audio recorder: \(error.localizedDescription)")
        }
    }
    
    func playRecording(_ title: String) {
        let audioFileURL = getAudioFileURL(for: title)
        
        do {
            switch playStatus {
            case .stop:
                audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                playStatus = .playing
                
                break
            case .pause:
                audioPlayer?.play(atTime: audioPlayer?.deviceCurrentTime ?? 0)
                playStatus = .playing
                
                break
            case .playing:
                break
            }
        } catch {
            print("Error initializing AVAudioPlayer: \(error.localizedDescription)")
        }
    }
    
    func pausePlayingRecording() {
        switch playStatus {
        case .stop, .pause:
            break
        case .playing:
            audioPlayer?.pause()
            playStatus = .pause
            
            break
        }
    }
    
    func clearCurrentPlay() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        currentRecordingTitle = ""
        playStatus = .stop
    }
}
