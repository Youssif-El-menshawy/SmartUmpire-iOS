//
//  MatchVoiceController.swift
//  SmartUmpire
//

import Foundation
import SwiftUI
import AudioToolbox


/// Bridges VoiceEngine (speech → text) with the current match:
/// - listens for final utterances from VoiceEngine
/// - parses them into VoiceIntent
/// - applies them via VoiceIntentDispatcher
/// - enforces a cooldown window after each valid command
final class MatchVoiceController {

    // MARK: - Dependencies

    private let engine: VoiceEngine
    private let parser = VoiceIntentParser()
    private let dispatcher: VoiceIntentDispatcher

    private let match: Match
    private let isPlayer1Serving: () -> Bool
    private let persistState: () -> Void


    // MARK: - Cooldown System

    private var cooldownActive = false
    private var cooldownTimer: Timer?
    private let cooldownSeconds: TimeInterval = 3
    private var lastAcceptedCommand: String = ""

    // MARK: - Init

    init(
   
        engine: VoiceEngine,
        match: Match,
        score: Binding<MatchScore>,
        context: Binding<TimerContext>,
        remaining: Binding<Int>,
        isPlayer1Serving: @escaping () -> Bool,
        startTimer: @escaping () -> Void,
        pauseTimer: @escaping () -> Void,
        resetTimer: @escaping () -> Void,
        addEvent: @escaping (EventItem) -> Void,
        persistState: @escaping () -> Void
    ) {
        self.engine = engine
        self.match = match
        self.isPlayer1Serving = isPlayer1Serving

        self.dispatcher = VoiceIntentDispatcher(
            match: match,
            score: score,
            context: context,
            remaining: remaining,
            isPlayer1Serving: isPlayer1Serving,
            startTimer: startTimer,
            pauseTimer: pauseTimer,
            resetTimer: resetTimer,
            addEvent: addEvent,
        )
        
        self.persistState = persistState

        // Connect VoiceEngine → Parser → Dispatcher
        engine.onUtterance = { [weak self] sentence in
            guard let self = self else { return }

            let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }

            if VOICE_DEBUG {
                print("\nRaw utterance:", cleaned)
            }

            // If cooldown active → ignore command
            if self.cooldownActive {
                if VOICE_DEBUG {
                    print("Ignored during cooldown:", cleaned)
                }
                return
            }

            // Parse command
            let intents = self.parser.parse(
                cleaned,
                match: self.match,
                isPlayer1Serving: self.isPlayer1Serving()
            )

            guard let intent = intents.first else {
                if VOICE_DEBUG {
                    print("Ignored utterance (no intent).")
                }
                return
            }

            if VOICE_DEBUG {
                print("Applying intent:", intent)
            }

            // Apply
            self.dispatcher.handle(intent)
            self.persistState()
            self.lastAcceptedCommand = cleaned
            
            // Play execution confirmation sound
            AudioServicesPlaySystemSound(1114)   // ← clean “success / confirmation” tone


            // Start cooldown
            self.startCooldown()
        }
    }

    // MARK: - Cooldown Logic

    private func startCooldown() {
        cooldownActive = true
        cooldownTimer?.invalidate()

        if VOICE_DEBUG {
            print("Cooldown started: \(cooldownSeconds)s")
        }

        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.endCooldown()
        }
    }

    private func endCooldown() {
        cooldownActive = false
        lastAcceptedCommand = ""
        cooldownTimer?.invalidate()
        cooldownTimer = nil

        // Reset captions AFTER cooldown ends
        DispatchQueue.main.async {
            self.engine.liveCaption = ""
        }

        if VOICE_DEBUG {
            print("Cooldown ended — ready for next command.")
        }
    }
}
