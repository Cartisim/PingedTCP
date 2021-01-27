struct Constants {
    
    #if DEBUG || LOCAL
    static let BASE_URL = "http://localhost:8080/api/"
    #else
    static let BASE_URL = "https://api.example.io/api/"
    #endif
}
