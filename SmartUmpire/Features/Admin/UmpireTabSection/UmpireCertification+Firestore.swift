//
//  Umpire+Firestore.swift
//  SmartUmpire
//
//  Created by Youssef on 24/12/2025.
//
import Foundation

extension UmpireCertification {
    var asDictionary: [String: Any] {
        [
            "id": id,
            "title": title,
            "issuer": issuer,
            "year": year,
            "active": active
        ]
    }
}
