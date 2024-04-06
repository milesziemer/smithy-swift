//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import struct Foundation.Data
import typealias SmithyReadWrite.DocumentWritingClosure
import typealias SmithyReadWrite.WritingClosure

public struct BodyMiddleware<OperationStackInput,
                             OperationStackOutput,
                             Writer>: Middleware {
    public let id: Swift.String = "BodyMiddleware"

    let documentWritingClosure: DocumentWritingClosure<OperationStackInput, Writer>
    let inputWritingClosure: WritingClosure<OperationStackInput, Writer>

    public init(
        documentWritingClosure: @escaping DocumentWritingClosure<OperationStackInput, Writer>,
        inputWritingClosure: @escaping WritingClosure<OperationStackInput, Writer>
    ) {
        self.documentWritingClosure = documentWritingClosure
        self.inputWritingClosure = inputWritingClosure
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

extension BodyMiddleware: RequestMessageSerializer {
    public typealias InputType = OperationStackInput
    public typealias RequestType = SdkHttpRequest
    public typealias AttributesType = HttpContext

    public func apply(input: OperationStackInput, builder: SdkHttpRequestBuilder, attributes: HttpContext) throws {
        do {
            let data = try documentWritingClosure(input, inputWritingClosure)
            builder.withBody(.data(data))
        } catch {
            throw ClientError.serializationFailed(error.localizedDescription)
        }
    }
}
