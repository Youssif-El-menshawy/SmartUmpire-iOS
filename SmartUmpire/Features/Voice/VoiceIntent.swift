//
//  VoiceIntent.swift
//  SmartUmpire
//

import Foundation

enum VoiceIntent: Equatable {
    // Timers
    case timerStart
    case timerPause
    case timerReset
    case timerContext(TimerContext)
    
    // Scoring – incremental
    case point(player: PlayerRef)
    case game(player: PlayerRef)
    
    // NEW: Advantage command
    case advantage(player: PlayerRef)
    
    // NEW: "All" scores (15 all, 30 all, 40 all)
    case scoreAll(score: String)
    
    // Server control
    case setServer(PlayerRef)
    
    // Sanctions / events
    case warning(player: PlayerRef)
    case violation(player: PlayerRef, reason: String?)
    
    // Undo
    case undoLast
    
    
    //SCORE
    case scoreSpoken(server: String, receiver: String)

}

enum PlayerRef: Equatable {
    case player1
    case player2
    case name(String)
    case role(Role)
    
    enum Role {
        case server
        case receiver
    }
}
