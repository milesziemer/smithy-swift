import io.kotest.matchers.string.shouldContainOnlyOnce
import org.junit.jupiter.api.Test
import software.amazon.smithy.swift.codegen.model.AddOperationShapes

class HttpUrlPathProviderTests {
    @Test
    fun `it builds url path provider smoke test`() {
        val context = setupTests("http-binding-protocol-generator-test.smithy")
        val contents = getModelFileContents("example", "SmokeTestInput+UrlPathProvider.swift", context.manifest)
        contents.shouldSyntacticSanityCheck()
        val expectedContents =
            """
            extension SmokeTestInput: ClientRuntime.URLPathProvider {
                public var urlPath: Swift.String? {
                    guard let label1 = label1 else {
                        return nil
                    }
                    return "/smoketest/\(label1.urlPercentEncoding())/foo"
                }
            }
            """.trimIndent()
        contents.shouldContainOnlyOnce(expectedContents)
    }

    private fun setupTests(smithyFile: String): TestContext {
        var model = javaClass.getResource(smithyFile).asSmithy()
        val settings = model.defaultSettings()
        model = AddOperationShapes.execute(model, settings.getService(model), settings.moduleName)
        val context = model.newTestContext()
        context.generator.generateSerializers(context.generationCtx)
        context.generator.generateProtocolClient(context.generationCtx)
        context.generator.generateDeserializers(context.generationCtx)
        context.generator.generateCodableConformanceForNestedTypes(context.generationCtx)
        context.generationCtx.delegator.flushWriters()
        return context
    }
}
