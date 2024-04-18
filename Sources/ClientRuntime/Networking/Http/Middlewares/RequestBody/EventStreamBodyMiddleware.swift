//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import struct Foundation.Data
import typealias SmithyReadWrite.DocumentWritingClosure
import typealias SmithyReadWrite.WritingClosure

public struct EventStreamBodyMiddleware<OperationStackInput,
                                        OperationStackOutput,
                                        OperationStackInputPayload: MessageMarshallable>:
                                        Middleware {
    public let id: Swift.String = "EventStreamBodyMiddleware"

    let keyPath: KeyPath<OperationStackInput, AsyncThrowingStream<OperationStackInputPayload, Swift.Error>?>
    let defaultBody: String?
    let marshalClosure: MarshalClosure<OperationStackInputPayload>
    let initialRequestMessage: EventStream.Message?

    public init(
        keyPath: KeyPath<OperationStackInput, AsyncThrowingStream<OperationStackInputPayload, Swift.Error>?>,
        defaultBody: String? = nil,
        marshalClosure: @escaping MarshalClosure<OperationStackInputPayload>,
        initialRequestMessage: EventStream.Message? = nil
    ) {
        self.keyPath = keyPath
        self.defaultBody = defaultBody
        self.marshalClosure = marshalClosure
        self.initialRequestMessage = initialRequestMessage
    }

    public func handle<H>(context: Context,
                          input: SerializeStepInput<OperationStackInput>,
                          next: H) async throws -> OperationOutput<OperationStackOutput>
    where H: Handler,
          Self.MInput == H.Input,
          Self.MOutput == H.Output,
          Self.Context == H.Context {
              try apply(input: input.operationInput, builder: input.builder, attributes: context)
              return try await next.handle(context: context, input: input)
          }

    public typealias MInput = SerializeStepInput<OperationStackInput>
    public typealias MOutput = OperationOutput<OperationStackOutput>
    public typealias Context = HttpContext
}

extension EventStreamBodyMiddleware: RequestMessageSerializer {
    public typealias InputType = OperationStackInput
    public typealias RequestType = SdkHttpRequest
    public typealias AttributesType = HttpContext

    public func apply(input: OperationStackInput, builder: SdkHttpRequestBuilder, attributes: HttpContext) throws {
        if let eventStream = input[keyPath: keyPath] {
            guard let messageEncoder = attributes.getMessageEncoder() else {
                fatalError("Message encoder is required for streaming payload")
            }
            guard let messageSigner = attributes.getMessageSigner() else {
                fatalError("Message signer is required for streaming payload")
            }
            let encoderStream = EventStream.DefaultMessageEncoderStream(
              stream: eventStream,
              messageEncoder: messageEncoder,
              marshalClosure: marshalClosure,
              messageSigner: messageSigner,
              initialRequestMessage: initialRequestMessage
            )
            builder.withBody(.stream(encoderStream))
        } else if let defaultBody {
            builder.withBody(.data(Data(defaultBody.utf8)))
        }
    }
}
