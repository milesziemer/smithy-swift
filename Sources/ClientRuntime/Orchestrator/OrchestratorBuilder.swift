//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

/// Builds an Orchestrator, combining runtime components, interceptors, serializers, and deserializers.
/// 
/// Note: This is intended to be used within generated code, not directly.
public class OrchestratorBuilder<
    InputType,
    OutputType,
    RequestType: RequestMessage,
    ResponseType: ResponseMessage,
    AttributesType: HasAttributes
> {
    /// A mutable container of the interceptors the orchestrator will use
    public var interceptors: Interceptors<RequestType, ResponseType, AttributesType> = Interceptors()

    internal var attributes: AttributesType?
    internal var serialize: (InputType, RequestType.RequestBuilderType, AttributesType) throws -> Void = { _, _, _ in }
    internal var deserialize: ((ResponseType, AttributesType) async throws -> Result<OutputType, Error>)?
    internal var retryStrategy: (any RetryStrategy)?
    internal var retryErrorInfoProvider: ((Error) -> RetryErrorInfo?)?
    internal var selectAuthScheme: (any SelectAuthScheme<AttributesType>)?
    internal var applyEndpoint: (any ApplyEndpoint<RequestType, AttributesType>)?
    internal var applySigner: (any ApplySigner<RequestType, AttributesType>)?
    internal var executeRequest: (any ExecuteRequest<RequestType, ResponseType, AttributesType>)?

    public init() {}

    /// - Parameter attributes: Attributes the orchestrator will provide to runtime components
    /// - Returns: Builder
    @discardableResult
    public func attributes(_ attributes: AttributesType) -> Self {
        self.attributes = attributes
        return self
    }

    /// - Parameter serializer: Function that performs part of request serialization
    /// - Returns: Builder
    @discardableResult
    public func serialize(
        _ serializer: @escaping (InputType, RequestType.RequestBuilderType, AttributesType) throws -> Void
    ) -> Self {
        let serialize = self.serialize
        self.serialize = { (input, builder, attributes) in
            try serialize(input, builder, attributes)
            try serializer(input, builder, attributes)
        }
        return self
    }

    /// - Parameter serializer: Runtime component that performs part of request serialization
    /// - Returns: Builder
    @discardableResult
    public func serialize(_ serializer: some RequestMessageSerializer<InputType, RequestType, AttributesType>) -> Self {
        return self.serialize(serializer.apply(input:builder:attributes:))
    }

    /// - Parameter deserializer: Function that performs response deserialization
    /// - Returns: Builder
    @discardableResult
    public func deserialize(_ deserializer: @escaping (ResponseType, AttributesType) async throws -> Result<OutputType, Error>) -> Self
    {
        self.deserialize = deserializer
        return self
    }

    /// - Parameter deserializer: Runtime component that performs response deserialization
    /// - Returns: Builder
    @discardableResult
    public func deserialize(
        _ deserializer: some ResponseMessageDeserializer<OutputType, ResponseType, AttributesType>
    ) -> Self {
        return self.deserialize(deserializer.deserialize(response:attributes:))
    }

    /// - Parameter retryStrategy: Runtime component that tells the orchestrator how to perform retries 
    /// - Returns: Builder
    @discardableResult
    public func retryStrategy(_ retryStrategy: any RetryStrategy) -> Self {
        self.retryStrategy = retryStrategy
        return self
    }

    /// - Parameter retryErrorInfoProvider: Function that turns operation errors into RetryErrorInfo
    /// - Returns: Builder
    @discardableResult
    public func retryErrorInfoProvider(_ retryErrorInfoProvider: @escaping (Error) -> RetryErrorInfo?) -> Self {
        self.retryErrorInfoProvider = retryErrorInfoProvider
        return self
    }

    /// - Parameter selectAuthScheme: Runtime component that selects the auth scheme
    /// - Returns: Builder
    @discardableResult
    public func selectAuthScheme(_ selectAuthScheme: some SelectAuthScheme<AttributesType>) -> Self {
        self.selectAuthScheme = selectAuthScheme
        return self
    }

    /// - Parameter selectAuthScheme: Function that selects the auth scheme
    /// - Returns: Builder
    @discardableResult
    public func selectAuthScheme(
        _ selectAuthScheme: @escaping (AttributesType) async throws -> SelectedAuthScheme?
    ) -> Self {
        self.selectAuthScheme = WrappedSelectAuthScheme(closure: selectAuthScheme)
        return self
    }

    /// - Parameter applyEndpoint: Runtime component that applies the endpoint to the request
    /// - Returns: Builder
    @discardableResult
    public func applyEndpoint(_ applyEndpoint: some ApplyEndpoint<RequestType, AttributesType>) -> Self {
        self.applyEndpoint = applyEndpoint
        return self
    }

    /// - Parameter applyEndpoint: Function that applies the endpoint to the request
    /// - Returns: Builder
    @discardableResult
    public func applyEndpoint(
        _ applyEndpoint: @escaping (RequestType, SelectedAuthScheme?, AttributesType) async throws -> RequestType
    ) -> Self {
        self.applyEndpoint = WrappedApplyEndpoint(closure: applyEndpoint)
        return self
    }

    /// - Parameter applySigner: Runtime component that applies the signer to the request
    /// - Returns: Builder
    @discardableResult
    public func applySigner(_ applySigner: some ApplySigner<RequestType, AttributesType>) -> Self {
        self.applySigner = applySigner
        return self
    }

    /// - Parameter applySigner: Function that applies the signer to the request
    /// - Returns: Builder
    @discardableResult
    public func applySigner(
        _ applySigner: @escaping (RequestType, SelectedAuthScheme?, AttributesType) async throws -> RequestType
    ) -> Self {
        self.applySigner = WrappedApplySigner(closure: applySigner)
        return self
    }

    /// - Parameter executeRequest: Runtime component that sends the request and receives the response
    /// - Returns: Builder
    @discardableResult
    public func executeRequest(_ executeRequest: some ExecuteRequest<RequestType, ResponseType, AttributesType>) -> Self
    {
        self.executeRequest = executeRequest
        return self
    }

    /// - Parameter executeRequest: Function that sends the request and receives the response
    /// - Returns: Builder
    @discardableResult
    public func executeRequest(
        _ executeRequest: @escaping (RequestType, AttributesType) async throws -> ResponseType
    ) -> Self {
        self.executeRequest = WrappedExecuteRequest(closure: executeRequest)
        return self
    }

    /// - Returns: Orchestrator
    public func build() -> Orchestrator<InputType, OutputType, RequestType, ResponseType, AttributesType> {
        return Orchestrator(builder: self)
    }
}
