//
//  AppState+AudioChatStreamOpenAIExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/06/2025.
//

import ARKit
import AVFoundation
import Foundation
import OpenAI
import RealityKit
import Speech

/// OpenAI extensions
extension AppState {
    /// Generates audio via the OpenAI TTS API, plays it from the therapist, then restarts listening if needed.
    @MainActor
    func generateAndPlayAudio(from text: String, automaticallyRestartAudioChatStream: Bool = false) async {
        do {
            print("Generating audio...")

            // Always stop speech recognition before TTS playback to avoid conflicts
            stopSpeechRecognition()

            self.audioConversation.isLucieSpeaking = true

            let audioQuery = AudioSpeechQuery(
                model: .tts_1,
                input: text,
                voice: .nova,
                responseFormat: .wav,
                speed: 1.0
            )
            let result = try await openAI.audioCreateSpeech(query: audioQuery)

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tts_output-\(UUID().uuidString).wav")
            try result.audio.write(to: outputURL)

            print("🔎 Audio file written at: \(outputURL.path)")
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
            print("🔎 File size: \(attrs?[.size] ?? -1) bytes")

            // Play back the audio using RealityKit (therapist entity)
            let config = AudioFileResource.Configuration(shouldLoop: false)
            let resourceName = "GeneratedAudio-\(UUID().uuidString)"
            let audioResource = try await AudioFileResource(
                contentsOf: outputURL,
                withName: resourceName,
                configuration: config
            )
            let audioPlaybackController = beeSceneState.therapist.playAudio(audioResource)
            audioPlaybackController.completionHandler = { [weak self] in
                // Clean up temporary audio file after playback
                try? FileManager.default.removeItem(at: outputURL)
                print("🧹 Cleaned up audio file.")

                Task { [weak self] in
                    // Stop pipeline and wait a bit
                    await self?.stopAudioConversationStreaming()
                    try? await Task.sleep(for: .milliseconds(1000))

                    await MainActor.run {
                        self?.audioConversation.audioStatus = .idle
                        self?.audioConversation.isStreaming = false
                        self?.audioConversation.isLucieSpeaking = false
                    }

                    if automaticallyRestartAudioChatStream {
                        if let step = self?.beeSceneState.step {
                            await self?.startAudioConversationStreaming(step: step)
                        }
                    }
                }
            }

            print("Audio generated and played!")
        } catch {
            print("Audio error:", error)
            self.audioConversation.isLucieSpeaking = false
        }
    }
}

@MainActor
extension AppState {
    enum AudioConversationStatus {
        case idle
        case listening
        case stopping
    }

    @Observable
    final class AudioConversation: Sendable {
        var isStreaming = false
        var transcribedText: String = "" // What the user said (microphone)
        var responseText: String = "" // What the AI replies
        var audioStatus: AppState.AudioConversationStatus = .idle
        var isLucieSpeaking: Bool = false
    }

    @MainActor
    func startAudioConversationStreaming(step: ImmersiveBeeSceneStep) async {
        isConversationStarted = true

        // Configure AVAudioSession for recording and playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            print("Audio session configured")
        } catch {
            print("Audio session error: \(error)")
            return
        }

        // Prevent duplicate streaming sessions
        guard audioConversation.isStreaming == false else {
            print("Streaming already active")
            return
        }
        audioConversation.isStreaming = true
        audioConversation.audioStatus = .listening
        audioConversation.transcribedText = ""

        // Prepare SFSpeechRecognizer and recognition request
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        // Create the AVAudioEngine
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else {
            print("No input node")
            return
        }
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("AudioEngine inputNode format: \(inputFormat)")
        if inputFormat.channelCount == 0 || inputFormat.sampleRate == 0 {
            print("Microphone is not available or not authorized")
            return
        }

        // Remove any existing tap before installing a new one (crash prevention)
        inputNode.removeTap(onBus: 0)

        // Prepare file URL for temporary audio recording
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("audio_streaming-\(UUID().uuidString).wav")
        audioFileURL = tmpURL
        var fileFormat: AVAudioFormat?

        // Start the speech recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if text.uppercased().contains("EXIT") {
                    print("🔑 EXIT keyword detected!")
                    self.exitWordDetected = true
                    NotificationCenter.default.post(name: .exitWordDetected, object: nil)
                }
                self.audioConversation.transcribedText = text
            }
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
            }
        }

        isFirstChunkReady = false

        // Install a tap on the input node with the native format
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            // Create the AVAudioFile on the first buffer, using the actual format
            if self.audioFile == nil {
                fileFormat = buffer.format
                self.audioFile = try? AVAudioFile(forWriting: tmpURL, settings: buffer.format.settings)
            }
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)

            if !self.isFirstChunkReady, buffer.frameLength > 0 {
                self.isFirstChunkReady = true
            }
        }

        // Prepare and start the audio engine
        do {
            audioEngine?.prepare()
            try audioEngine?.start()
            print("Audio engine started")
        } catch {
            print("❌ Failed to start AVAudioEngine: \(error)")
            return
        }

        // Start the streaming task for audio chunks (OpenAI Whisper, etc.)
        streamingTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            while await self.audioConversation.isStreaming {
                try? await Task.sleep(for: .seconds(5))
                guard await self.isFirstChunkReady else {
                    print("⏩ Waiting for first chunk")
                    continue
                }
                await self.streamAudioChunkToOpenAI(step: step)
            }
        }
    }

    func stopAudioConversationStreaming() async {
        audioConversation.isStreaming = false
        audioConversation.audioStatus = .stopping

        streamingTask?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        audioFile = nil
        audioFileURL = nil

        await MainActor.run {
            audioConversation.audioStatus = .idle
        }
        print("Audio streaming stopped and cleaned")
    }

    // Send the current buffer to OpenAI, then puts the file to 0 for the next chunk
    @MainActor
    private func streamAudioChunkToOpenAI(step: ImmersiveBeeSceneStep) async {
        guard audioConversation.isStreaming, let url = audioFileURL else {
            print("⏩ [STREAM] Not streaming or no audio file, skipping chunk")
            return
        }

        guard let url = audioFileURL else {
            print("❌ audioFileURL is nil in streamAudioChunkToOpenAI")
            return
        }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            print("❌ audioFileURL file is empty or can't be loaded: \(url)")
            return
        }

        guard data.count > 10000 else { // ~0.1 sec à 48kHz mono float32
            print("⏩ Skipping audio chunk: too short (\(data.count) bytes)")
            return
        }

        // Extract file extension, not full name!
        let ext = url.pathExtension.lowercased()
        guard let fileType = AudioTranscriptionQuery.FileType(rawValue: ext) else {
            print("❌ Unknown file extension for Whisper: \(ext) for url \(url)")
            return
        }
        print("🔎 Streaming audio chunk (\(data.count) bytes), ext: \(ext), fileType: \(fileType.rawValue)")

        // Transcribing the text with Whisper
        let query = AudioTranscriptionQuery(
            file: data,
            fileType: fileType,
            model: .whisper_1,
            prompt: nil,
            temperature: nil,
            language: "en"
        )
        do {
            let transcription = try await openAI.audioTranscriptions(query: query)
            let transcript = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Whisper transcript: '\(transcript)'")

            // guard transcript.count >= 4 else {
            //     print("⏩ Transcript too short (\(transcript.count) chars), skipping chat request.")
            //     return
            // }

            // Add the transcript on the user side
            await MainActor.run {
                if !transcript.isEmpty {
                    if !self.audioConversation.transcribedText.isEmpty {
                        self.audioConversation.transcribedText += "\n"
                    }
                    self.audioConversation.transcribedText += transcript
                }
                // Prepare the UI for the new answer of the IA
                self.audioConversation.responseText = ""
            }

            let stepPresentation = step.offlineStepPresentationText()
            let stepInstructions = step.offlineStepInstructionText()
            let stateSummary = """
            isCurrentStepConfirmedForWaterBottleChallengeOrPicnicExperienceStep: \(beeSceneState.step.isCurrentStepConfirmed) - (If confirmed, it means that the user has started the current step challenge (Water Bottle Challenge or Picnic Experience).
            isWaterBottlePlacedOnHaloForWaterBottleChallengeStep: \(beeSceneState.isWaterBottlePlacedOnHalo)
            hasBeeFlownAwayInPicnicExperienceStep: \(beeSceneState.hasBeeFlownAway) - (Used in the Picnic Experience step. When the bee has flown away, it means the experience has been successful.)
            """

            let systemPrompt = """
            \(AppState.therapistInstructions)

            ==== SCENARIO OVERVIEW ====
            \(AppState.beeScenarioStepList)
            ==========================

            ===== CURRENT USER CONTEXT =====
            Current step: \(step)
            Step presentation: \(stepPresentation)
            Step instructions: \(stepInstructions ?? "None")
            Runtime state:
            \(stateSummary)
            ===============================

            Behavolve application global context:
            \(AppState.behavolveAppDescription)
            """

            let messages: [ChatQuery.ChatCompletionMessageParam] = [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(content: .string(transcript)))
            ]
            let chatQuery = ChatQuery(messages: messages, model: .gpt4_o, stream: true)
            print("🧠 Sending to GPT: \(transcript)")
            for try await result in openAI.chatsStream(query: chatQuery) {
                for choice in result.choices {
                    if let text = choice.delta.content, !text.isEmpty {
                        await MainActor.run {
                            self.audioConversation.responseText += text
                        }
                    }
                }
            }
            print("✅ GPT response finished: \(audioConversation.responseText)")
            if AppState.ChatGptAudioEnabled, !audioConversation.responseText.isEmpty {
                await self.generateAndPlayAudio(from: audioConversation.responseText)
            }
        } catch {
            print("Audio streaming error: \(error)")
        }

        // Empty/Reset the file for the next Chunk
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("❌ Failed to remove file: \(url) – \(error)")
        }
        guard let inputNode = audioEngine?.inputNode else {
            print("❌ audioEngine or inputNode is nil when resetting file")
            return
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
            print("🔄 AVAudioFile reset for next chunk at \(url)")
        } catch {
            print("❌ Failed to recreate AVAudioFile for new chunk: \(error)")
            audioFile = nil
        }
    }
}

// MARK: - Audio Conversation Microphone Pipeline (Reco Only)

@MainActor
extension AppState {
    func startSpeechRecognition() async {
        guard audioConversation.audioStatus != .listening else { return }

        // Configure AVAudioSession for recording
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else { return }
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioConversation.audioStatus = .listening

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.audioConversation.transcribedText = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopSpeechRecognition()
            }
        }

        audioEngine?.prepare()
        try? audioEngine?.start()
        print("Speech reco started")
    }

    func stopSpeechRecognition() {
        audioConversation.audioStatus = .idle
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        print("Speech reco stopped")
    }
}
