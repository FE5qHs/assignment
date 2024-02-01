//
//  ViewController.swift
//  assignment
//
//  Created by cz on 2024/1/30.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController {
    var textView = UITextView()
    var recordButton = UIButton()
    var tableView = UITableView()
    
    var audioRecorder: AVAudioRecorder?
    var audioEngine = AVAudioEngine()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioPlayer: AVAudioPlayer?
    
    var isRecording = false
    var isInBackground = false
    
    var currentRecordingTitle = ""
    var currentDateString = ""
    var playStatus = PlayStatus.stop
    var recordingList = [String]()

    enum PlayStatus {
        case playing
        case pause
        case stop
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSpeech()
        loadRecordingList()
        
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
    
    // MARK: setup
    
    func setupUI() {
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        recordButton.setTitle("Start Recording", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = .red
        recordButton.addTarget(
            self,
            action: #selector(recordButtonTapped),
            for: .touchUpInside
        )
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordButton)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RecordingCell.self, forCellReuseIdentifier: "RecordingCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            recordButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recordButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            recordButton.heightAnchor.constraint(equalToConstant: 50),
            
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),

            tableView.topAnchor.constraint(equalTo: textView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -16)
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
    
    func loadRecordingList() {
        recordingList.removeAll()

        let documentsDirectory = getDocumentsDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)
            let audioFiles = files.filter { $0.hasSuffix(".m4a") }

            recordingList.append(contentsOf: audioFiles)
            recordingList.sort()
        } catch {
            print("Error reading local audio files: \(error)")
        }

        tableView.reloadData()
    }
    
    // MARK: alert
    func showPermissionAlert() {
        let alertController = UIAlertController(
            title: "Microphone permission required to transcribe text",
            message: nil,
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)

        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(
                    settingsURL,
                    options: [:],
                    completionHandler: nil
                )
            }
        }
        alertController.addAction(settingsAction)

        present(alertController, animated: true, completion: nil)
    }
    
    func showRecordingInProgressAlert() {
        let alertController = UIAlertController(
            title: "Recording in progress",
            message: nil,
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)

        present(alertController, animated: true, completion: nil)
    }

    // MARK: Life cycle
    
    @objc func appWillResignActive() {
        isInBackground = true
        
        pausePlayingRecording()
    }

    @objc func appDidBecomeActive() {
        if isInBackground, isRecording {
            showRecordingInProgressAlert()
        }
        isInBackground = false
    }
    
    // MARK: Common Recording method
    
    @objc func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        isRecording = true
        setupAudioRecorder()
        clearCurrentPlay()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .record,
                mode: .default,
                options: []
            )
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

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        audioEngine.stop()
        
        recognitionRequest?.endAudio()
        
        isRecording = false
        
        recordButton.setTitle("Start Recording", for: .normal)

        updateRecordingList(with: currentDateString)
    }

    func updateRecordingList(with dateString: String) {
        recordingList.append(dateString + ".m4a")

        tableView.reloadData()

        if tableView.numberOfRows(inSection: 0) > recordingList.count - 1 {
            let indexPath = IndexPath(row: recordingList.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    // MARK: Tool method
    
    func getAudioFileURL(for title: String) -> URL {
        let documentsDirectory = getDocumentsDirectory()
        return documentsDirectory.appendingPathComponent("\(title)")
    }

    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordingList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "RecordingCell",
            for: indexPath
        ) as? RecordingCell else {
            return UITableViewCell()
        }
        
        cell.titleLabel.text = recordingList[indexPath.row]
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRecordingTitle = recordingList[indexPath.row]

        if currentRecordingTitle.isEmpty {
            playRecording(selectedRecordingTitle)
        } else if currentRecordingTitle == selectedRecordingTitle {
            switch playStatus {
            case .playing:
                pausePlayingRecording()
                
                break
            case .pause, .stop:
                playRecording(selectedRecordingTitle)
                
                break
            }
        } else {
            clearCurrentPlay()
            playRecording(selectedRecordingTitle)
        }
        
        currentRecordingTitle = selectedRecordingTitle
    }
}
