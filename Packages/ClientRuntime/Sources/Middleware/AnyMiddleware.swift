// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0.

/// type erase the Middleware protocol
public struct AnyMiddleware<MInput, MOutput, Context: MiddlewareContext>: Middleware {
    
    private let _handle: (Context, MInput, AnyHandler<MInput, MOutput, Context>) async throws -> MOutput

    public var id: String

    public init<M: Middleware>(_ realMiddleware: M)
    where M.MInput == MInput, M.MOutput == MOutput, M.Context == Context {
        if let alreadyErased = realMiddleware as? AnyMiddleware<MInput, MOutput, Context> {
            self = alreadyErased
            return
        }

        self.id = realMiddleware.id
        self._handle = realMiddleware.handle
    }
    
    public init<H: Handler>(handler: H, id: String) where H.Input == MInput,
                                                          H.Output == MOutput,
                                                          H.Context == Context {
        
        self._handle = { context, input, handler in
            try await handler.handle(context: context, input: input)
        }
        self.id = id
    }

    public func handle<H: Handler>(context: Context, input: MInput, next: H) async throws -> MOutput
    where H.Input == MInput,
          H.Output == MOutput,
          H.Context == Context {
        return try await _handle(context, input, next.eraseToAnyHandler())
    }
}
