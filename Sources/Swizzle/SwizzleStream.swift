//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/8/23.
//

import Foundation
import AVFoundation
import Speech

#if canImport(UIKit)
public class SwizzleStream{
    @Published var transcript: String = ""
    private var speechRecognizer = SpeechRecognizer()

    public func startSpeechRecognition() {
        Task {
            await speechRecognizer.startTranscribing()
        }
    }
    
    public func stopSpeechRecognition() -> String{
        let transcript = speechRecognizer.transcript
        Task {
            await speechRecognizer.stopTranscribing()
            await speechRecognizer.resetTranscript()
        }
        return transcript
    }
    
    public init(){ }

}
#endif
