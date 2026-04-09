//
//  ApiConfig.swift
//  TrainLog
//

import Foundation

/// Base URL бэкенда. Читается из Info.plist (ключ APIBaseURL или INFOPLIST_KEY_APIBaseURL в настройках таргета).
enum ApiConfig {
    static var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: urlString) else {
            return URL(string: "https://train.tallybase.ru")!
        }
        return url
    }
}
