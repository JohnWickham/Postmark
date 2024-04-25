//
//  Logger.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Logging
import ArgumentParser

class Log {
    public static var shared = {
        var logger = Logger(label: "com.wickham.Postmark")
        logger.logLevel = .info
        return logger
    }()
}

extension Logger.Level: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }
}
