//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/8/23.
//

import Foundation

#if canImport(UIKit)
class SwizzleStream{
    @Published var transcript: String = ""
    private var speechRecognizer = SpeechRecognizer()

    public func startSpeechRecognition() {
        Task {
            await speechRecognizer.startTranscribing()
        }
    }
    
    init(){ }

}
#endif
