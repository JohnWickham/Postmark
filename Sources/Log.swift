//
//  Logger.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Logging

class Log {
    public static let shared = {
        var logger = Logger(label: "com.wickham.Postmark")
        logger.logLevel = .trace
        return logger
    }()
}
