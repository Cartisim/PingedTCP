import Foundation

struct MessageRequest: Codable {
    var avatar: String?
    var contactID: String
    var fullName: String
    var message: String
    var chatSessionID: String
    
    init(avatar: String, contactID: String, fullName: String, message: String, chatSessionID: String) {
        self.avatar = avatar
        self.contactID = contactID
        self.fullName = fullName
        self.message = message
        self.chatSessionID = chatSessionID
        
    }
}

