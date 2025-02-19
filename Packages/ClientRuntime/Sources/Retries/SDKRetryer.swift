//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
import AwsCommonRuntimeKit

public class SDKRetryer: Retryer {
    let crtRetryStrategy: CRTAWSRetryStrategy
    private let sharedDefaultIO: SDKDefaultIO = SDKDefaultIO.shared
    
    public init(options: RetryOptions) throws {
        self.crtRetryStrategy = try CRTAWSRetryStrategy(options: options.toCRTType())
    }
    
    public convenience init() throws {
        let backOffOptions = ExponentialBackOffRetryOptions()
        let retryOptions = RetryOptions(backOffRetryOptions: backOffOptions)
        try self.init(options: retryOptions)
    }
    
    public func acquireToken(partitionId: String) async throws -> RetryToken {
        let token = try await crtRetryStrategy.acquireToken(partitionId: partitionId)
        return RetryToken(crtToken: token)
    }
    
    public func scheduleRetry(token: RetryToken, error: RetryError) async throws -> RetryToken {
        let token = try await crtRetryStrategy.scheduleRetry(token: token.crtToken, errorType: error.toCRTType())
        return RetryToken(crtToken: token)
    }
    
    public func recordSuccess(token: RetryToken) {
        crtRetryStrategy.recordSuccess(token: token.crtToken)
    }
    
    @available(*, deprecated, message: "This function will be removed soon.")
    public func releaseToken(token: RetryToken) {
    }
    
    public func isErrorRetryable<E>(error: SdkError<E>) -> Bool {
        switch error {
        case .client(let clientError, _) :
            switch clientError {
            case .networkError, .crtError:
                return true
            default:
                return false
            }
        case .service(let serviceError, let httpResponse):
            if httpResponse.headers.exists(name: "x-amz-retry-after") {
                return true
            }
            
            if let serviceError = serviceError as? ServiceError {
                return serviceError._retryable
            }
            
            if httpResponse.statusCode.isRetryable {
                return true
            }
            return false
        case .unknown:
            return false
        }
    }
    
    public func getErrorType<E>(error: SdkError<E>) -> RetryError {
        switch error {
        case .client(let clientError, _) :
            if case ClientError.crtError = clientError {
                return .transient
            }
            return .clientError

        case .service(let serviceError, let httpResponse):
            if httpResponse.headers.exists(name: "x-amz-retry-after") {
                return .serverError
            }
            
            if let serviceError = serviceError as? ServiceError {
                if serviceError._isThrottling {
                    return .throttling
                }
                return .serverError
            }
            
            if httpResponse.statusCode.isRetryable {
                return .transient
            }
            
            return .serverError
        case .unknown:
            return .clientError
        }
    }
}
