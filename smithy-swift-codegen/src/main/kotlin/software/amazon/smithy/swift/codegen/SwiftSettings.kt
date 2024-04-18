/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0.
 */

package software.amazon.smithy.swift.codegen

import software.amazon.smithy.codegen.core.CodegenException
import software.amazon.smithy.model.Model
import software.amazon.smithy.model.knowledge.ServiceIndex
import software.amazon.smithy.model.node.ObjectNode
import software.amazon.smithy.model.node.StringNode
import software.amazon.smithy.model.shapes.ServiceShape
import software.amazon.smithy.model.shapes.Shape
import software.amazon.smithy.model.shapes.ShapeId
import java.util.logging.Logger
import kotlin.streams.toList

private const val SERVICE = "service"
private const val MODULE_NAME = "module"
private const val MODULE_VERSION = "moduleVersion"
private const val MODULE_DESCRIPTION = "moduleDescription"
private const val AUTHOR = "author"
private const val HOMEPAGE = "homepage"
// If SDK_ID is not provided by the service model, the value of sdkId defaults to the Service's shape id name.
private const val SDK_ID = "sdkId"
private const val GIT_REPO = "gitRepo"
private const val SWIFT_VERSION = "swiftVersion"
private const val USE_INTERCEPTORS = "useInterceptors"

class SwiftSettings(
    val service: ShapeId,
    val moduleName: String,
    val moduleVersion: String,
    val moduleDescription: String,
    val author: String,
    val homepage: String,
    val sdkId: String,
    val gitRepo: String,
    val swiftVersion: String,
    var useInterceptors: Boolean
) {

    companion object {

        private val LOGGER: Logger = Logger.getLogger(SwiftSettings::class.java.name)

        /**
         * Create settings from a configuration object node.
         *
         * @param model Model to infer the service from (if not explicitly set in config)
         * @param config Config object to load
         * @throws software.amazon.smithy.model.node.ExpectationNotMetException
         * @return Returns the extracted settings
         */
        fun from(model: Model, config: ObjectNode): SwiftSettings {
            config.warnIfAdditionalProperties(
                listOf(
                    SERVICE,
                    MODULE_NAME,
                    MODULE_DESCRIPTION,
                    MODULE_VERSION,
                    AUTHOR,
                    SDK_ID,
                    HOMEPAGE,
                    GIT_REPO,
                    SWIFT_VERSION,
                    USE_INTERCEPTORS
                )
            )

            val serviceId = config.getStringMember(SERVICE)
                .map(StringNode::expectShapeId)
                .orElseGet { inferService(model) }

            val moduleName = config.expectStringMember(MODULE_NAME).value
            val version = config.expectStringMember(MODULE_VERSION).value
            val desc = config.getStringMemberOrDefault(MODULE_DESCRIPTION, "$moduleName client")
            val homepage = config.expectStringMember(HOMEPAGE).value
            val author = config.expectStringMember(AUTHOR).value
            val gitRepo = config.expectStringMember(GIT_REPO).value
            val swiftVersion = config.expectStringMember(SWIFT_VERSION).value
            val sdkId = sanitizeSdkId(config.getStringMemberOrDefault(SDK_ID, serviceId.name))
            val useInterceptors = config.getBooleanMemberOrDefault(USE_INTERCEPTORS)

            return SwiftSettings(serviceId, moduleName, version, desc, author, homepage, sdkId, gitRepo, swiftVersion, useInterceptors)
        }

        private fun sanitizeSdkId(sdkId: String): String {
            return sdkId.removeSuffix(" Service")
        }

        // infer the service to generate from a model
        private fun inferService(model: Model): ShapeId {
            val services = model.shapes(ServiceShape::class.java)
                .map(Shape::getId)
                .sorted()
                .toList()

            when {
                services.isEmpty() -> {
                    throw CodegenException(
                        "Cannot infer a service to generate because the model does not " +
                            "contain any service shapes"
                    )
                }
                services.size > 1 -> {
                    throw CodegenException(
                        "Cannot infer service to generate because the model contains " +
                            "multiple service shapes: " + services
                    )
                }
                else -> {
                    val service = services[0]
                    LOGGER.info("Inferring service to generate as: $service")
                    return service
                }
            }
        }
    }

    /**
     * Gets the corresponding [ServiceShape] from a model.
     *
     * @param model Model to search for the service shape by ID.
     * @return Returns the found `Service`.
     * @throws NullPointerException if the service has not been set.
     * @throws CodegenException if the service is invalid or not found.
     */
    fun getService(model: Model): ServiceShape {
        return model
            .getShape(this.service)
            .orElseThrow { CodegenException("Service shape not found: " + this.service) }
            .asServiceShape()
            .orElseThrow { CodegenException("Shape is not a Service: " + this.service) }
    }

    /**
     * Resolves the highest priority protocol from a service shape that is
     * supported by the generator.
     *
     * @param serviceIndex Service index containing the support
     * @param service Service to get the protocols from if "protocols" is not set.
     * @param supportedProtocolTraits The set of protocol traits supported by the generator.
     * @return Returns the resolved protocol name.
     * @throws UnresolvableProtocolException if no protocol could be resolved.
     */
    fun resolveServiceProtocol(
        serviceIndex: ServiceIndex,
        service: ServiceShape,
        supportedProtocolTraits: Set<ShapeId>
    ): ShapeId {
        val resolvedProtocols: Set<ShapeId> = serviceIndex.getProtocols(service).keys
        val protocol = resolvedProtocols.firstOrNull(supportedProtocolTraits::contains)
        return protocol ?: throw UnresolvableProtocolException(
            "The ${service.id} service supports the following unsupported protocols $resolvedProtocols. " +
                "The following protocol generators were found on the class path: $supportedProtocolTraits"
        )
    }
}

class UnresolvableProtocolException(message: String) : CodegenException(message)

val SwiftSettings.testModuleName: String
    get() {
        return "${this.moduleName}Tests"
    }
