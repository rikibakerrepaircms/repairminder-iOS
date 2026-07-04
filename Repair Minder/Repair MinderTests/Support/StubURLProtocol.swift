import Foundation

/// Test-only network stub for view models that hit `URLSession.shared` directly instead of
/// going through `InventoryServing`/`APIClient` (e.g. `BuybackListViewModel`,
/// `BuybackDetailViewModel`). Registered process-wide via `URLProtocol.registerClass`, which
/// Foundation's default URL-loading system consults for sessions using `.default`
/// configuration — including `URLSession.shared`. No production code is touched; this only
/// intercepts at the URL-loading layer for the duration of a test.
final class StubURLProtocol: URLProtocol {
    /// Set by each test before exercising the VM. Receives the outgoing request and returns
    /// (status code, response body). Reset in `tearDown` to avoid leaking between tests.
    static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                        headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
