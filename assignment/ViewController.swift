//
//  ViewController.swift
//  assignment
//
//  Created by cz on 2024/1/30.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    private var textView = UITextView()
    private var recordButton = UIButton()
    
    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var isRecording = false
    private var isInBackground = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSpeech()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupUI() {
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        recordButton.setTitle("Start Recording", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = .red
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordButton)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -16),

            recordButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recordButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            recordButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    func setupSpeech() {
        speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation { [weak self] in
                guard let self else {
                    return
                }
                
                switch authStatus {
                case .authorized:
                    // Microphone permission already granted
                    break
                case .denied, .restricted:
                    // Microphone permission denied
                    self.showPermissionAlert()
                    
                    self.recordButton.backgroundColor = .gray
                    self.recordButton.isUserInteractionEnabled = false
                case .notDetermined:
                    // Microphone permission not determined, request permission
                    self.requestMicrophonePermission()
                @unknown default:
                    break
                }
            }
        }
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self else {
                return
            }
            
            if !granted {
                // Microphone permission denied
                self.showPermissionAlert()
            }
        }
    }

    func showPermissionAlert() {
        let alertController = UIAlertController(
            title: "Microphone permission required to transcribe text",
            message: nil,
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)

        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(settingsAction)

        present(alertController, animated: true, completion: nil)
    }

    @objc func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        isRecording = true
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup error: \(error)")
            isRecording = false
            return
        }

        // Stop any existing recognition task
        recognitionTask?.cancel()
        
        // Create a new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        audioEngine = AVAudioEngine()

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { [weak self] (buffer, when) in
            guard let self, !self.isInBackground else {
                return
            }
            
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start error: \(error)")
            isRecording = false
        }

        recordButton.setTitle("Stop Recording", for: .normal)
        
        startSpeechRecognition()
    }

    
    func startSpeechRecognition() {
        guard let recognitionRequest, let speechRecognizer else { return }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else {
                return
            }
            
            var isFinal = false

            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                isFinal = result.isFinal

                // Update UI on the main thread to avoid conflicts
                DispatchQueue.main.async {
                    if !isFinal {
                        // If not final result, append the new text to the existing text
                        self.textView.text = recognizedText
                    } else {
                        // If final result, append the final result and a new line for the next recognized speech
                        self.textView.text = recognizedText + "\n"
                    }

                    // Scroll to the bottom to show the latest recognized speech
                    let range = NSRange(location: self.textView.text.count - 1, length: 1)
                    self.textView.scrollRangeToVisible(range)
                }
            }

            if error != nil || isFinal {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        recordButton.setTitle("Start Recording", for: .normal)
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        recordButton.isEnabled = available
    }

    @objc func appWillResignActive() {
        isInBackground = true
    }

    @objc func appDidBecomeActive() {
        isInBackground = false
    }
}
