import Foundation

struct MessageResponse: Codable {
    var avatar: String?
    var contactID: String
    var fullName: String
    var message: String
    var token: String
    var sessionID: String
    var chatSessionID: String
    
    init(avatar: String, contactID: String, fullName: String, message: String, token: String, sessionID: String, chatSessionID: String) {
        self.avatar = avatar
        self.contactID = contactID
        self.fullName = fullName
        self.message = message
        self.token = token
        self.sessionID = sessionID
        self.chatSessionID = chatSessionID
    }
}

