import Foundation
import NIO
import AsyncHTTPClient

/// This `ChannelInboundHandler` demonstrates a few things:
///   * Synchronisation between `EventLoop`s.
///   * Mixing `Dispatch` and SwiftNIO.
///   * `Channel`s are thread-safe, `ChannelHandlerContext`s are not.
///
/// As we are using an `MultiThreadedEventLoopGroup` that uses more then 1 thread we need to ensure proper
/// synchronization on the shared state in the `ChatHandler` (as the same instance is shared across
/// child `Channel`s). For this a serial `DispatchQueue` is used when we modify the shared state (the `Dictionary`).
/// As `ChannelHandlerContext` is not thread-safe we need to ensure we only operate on the `Channel` itself while
/// `Dispatch` executed the submitted block.
struct OurDate: Decodable {
    let ourString: String
}

final class ChatHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
    private var channels: [ObjectIdentifier: Channel] = [:]
    
    
    
    
    
    public func channelActive(context: ChannelHandlerContext) {
        print("ACTIVE")
        let channel = context.channel
        self.channelsSyncQueue.async { [self] in
            self.channels[ObjectIdentifier(channel)] = channel
        }
        context.fireChannelActive()
    }
    
    public func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        print("CLOSE", context.channel, mode)
        context.close(mode: mode, promise: promise)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        print(channel, "INACTIVE")
        self.channelsSyncQueue.async {
            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
                self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - Client disconnected\n")
            }
        }
        context.fireChannelInactive()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("ERROR", context.channel, error)
        context.fireErrorCaught(error)
    }
    

    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var read = self.unwrapInboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: read.readableBytes + 64)
        guard let received = read.readString(length: read.readableBytes) else {return}
        buffer.writeString("\(received)")
        print(received, "Received On Post Message")
        //        do {
        let object = try? JSONDecoder().decode(EncryptedAuthRequest.self, from: buffer)
        guard let decryptedObject = CartisimCrypto.decryptableResponse(ChatroomRequest.self, string: object!.encryptedObject) else {return}
        var request = try! HTTPClient.Request(url: "\(Constants.BASE_URL)postMessage/\(decryptedObject.sessionID)", method: .POST)
        
        request.headers.add(name: "User-Agent", value: "Swift HTTPClient")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Authorization", value: "Bearer \(decryptedObject.token)")
        request.headers.add(name: "Connection", value: "keep-alive")
        request.headers.add(name: "Content-Length", value: "")
        request.headers.add(name: "Date", value: "\(Date())")
        request.headers.add(name: "Server", value: "TCPCartisim")
        request.headers.add(name: "content-security-policy", value: "default-src 'none'")
        request.headers.add(name: "x-content-type-options", value: "nosniff")
        request.headers.add(name: "x-frame-options", value: "DENY")
        request.headers.add(name: "x-xss-protection", value: "1; mode=block")
        
        guard let body = try? JSONEncoder().encode(object) else {return}
        request.body = .data(body)
        TCPServer.httpClient?.execute(request: request).map { result in
            if result.status == .ok {
                print(result, "Response")
                self.channelsSyncQueue.async {
                    guard let data = result.body else {return}
                    self.writeToAll(channels: self.channels, buffer: data)
                }
            } else {
                print(result.status, "Remote Error")
            }
        }.whenFailure { (error) in
            print(error, "Error in Chat handler")
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    private func writeToAll(channels: [ObjectIdentifier: Channel], allocator: ByteBufferAllocator, message: String) {
        let buffer =  allocator.buffer(string: message)
        self.writeToAll(channels: channels, buffer: buffer)
    }
    
    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
}

