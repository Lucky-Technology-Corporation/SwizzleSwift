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
    private var player: AVPlayer?
    @Published var transcript: String = ""
    private var speechRecognizer = SpeechRecognizer()

    public func startSpeechRecognition() {
        Task {
            await speechRecognizer.startTranscribing()
        }
    }
    
    public func stopSpeechRecognition() async -> String {
        return await Task<String, Never> {
            let transcript = await speechRecognizer.getTranscript()
            await speechRecognizer.stopTranscribing()
            await speechRecognizer.resetTranscript()
            return transcript
        }.value
    }
    
    public func playAudio(from functionName: String, with parameters: [String: String]?, completion: @escaping (Bool, Error?) -> Void) {
        
        let baseUrl = Swizzle.shared.apiBaseURL?.appendingPathComponent(functionName)
        
        var queryUrl: URL!
        if let params = parameters{
            queryUrl = addQueryParameters(params, to: baseUrl!)
        } else{
            queryUrl = baseUrl
        }
        
        let asset = AVAsset(url: queryUrl)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Add an observer to know when the audio finishes playing
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            completion(true, nil)
        }
        
        player = AVPlayer(playerItem: playerItem)
        player?.play()
    }

    func addQueryParameters(_ params: [String: String], to baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        
        components?.queryItems = params.map { (key, value) in
            return URLQueryItem(name: key, value: value)
        }
        
        return components?.url
    }
    
    public init(){ }

}

class AudioPlayer {
    private var player: AVPlayer?
    
    func playAudio(from url: URL, completion: @escaping (Bool, Error?) -> Void) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Add an observer to know when the audio finishes playing
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            completion(true, nil)
        }
        
        player = AVPlayer(playerItem: playerItem)
        player?.play()
    }
}

#endif
