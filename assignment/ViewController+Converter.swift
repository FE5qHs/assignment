//
//  ViewController+Convertor.swift
//  assignment
//
//  Created by cz on 2024/2/1.
//

import Foundation
import Speech

extension ViewController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        recordButton.isEnabled = available
    }
}

extension ViewController {
    func startSpeechRecognition() {
        guard let recognitionRequest, let speechRecognizer else { return }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self, let result else {
                return
            }

            let recognizedText = result.bestTranscription.formattedString

            // Update UI on the main thread to avoid conflicts
            DispatchQueue.main.async {
                self.textView.text = recognizedText + "\n"

                // Scroll to the bottom to show the latest recognized speech
                let range = NSRange(location: self.textView.text.count - 1, length: 1)
                self.textView.scrollRangeToVisible(range)
            }
        }
    }
}
