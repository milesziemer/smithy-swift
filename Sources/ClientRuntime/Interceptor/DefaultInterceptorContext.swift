//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

/// Default implementation for all interceptor context types.
///
/// This object will be created before operation execution, and passed through each interceptor
/// hook in the execution pipeline.
public class DefaultInterceptorContext<
    RequestType: RequestMessage,
    ResponseType: ResponseMessage,
    AttributesType: HasAttributes
>: InterceptorContext {
    private var attributes: AttributesType
    private var input: Any
    private var request: RequestType?
    private var response: ResponseType?
    private var result: Result<Any, Error>?

    public init(input: Any, attributes: AttributesType) {
        self.input = input
        self.attributes = attributes
    }

    public func getInput() -> Any {
        self.input
    }

    public func getAttributes() -> AttributesType {
        return self.attributes
    }
}

extension DefaultInterceptorContext: BeforeSerialization {}

extension DefaultInterceptorContext: MutableInput {
    public func updateInput(updated: Any) {
        self.input = updated
    }
}

extension DefaultInterceptorContext: AfterSerialization {
    public func getRequest() -> RequestType {
        self.request!
    }
}

extension DefaultInterceptorContext: MutableRequest {
    public func updateRequest(updated: RequestType) {
        self.request = updated
    }
}

extension DefaultInterceptorContext: BeforeDeserialization {
    public func getResponse() -> ResponseType {
        self.response!
    }
}

extension DefaultInterceptorContext: MutableResponse {
    public func updateResponse(updated: ResponseType) {
        self.response = updated
    }
}

extension DefaultInterceptorContext: AfterDeserialization {
    public func getResult() -> Result<Any, Error> {
        self.result!
    }
}

extension DefaultInterceptorContext: AfterAttempt {
    public func getResponse() -> ResponseType? {
        self.response
    }
}

extension DefaultInterceptorContext: MutableOutputAfterAttempt {
    public func updateResult(updated: Result<Any, Error>) {
        self.result = updated
    }
}

extension DefaultInterceptorContext: Finalization {
    public func getRequest() -> RequestType? {
        self.request
    }
}

extension DefaultInterceptorContext: MutableOutputFinalization {}
