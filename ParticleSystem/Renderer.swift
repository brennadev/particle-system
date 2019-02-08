//
//  Renderer.swift
//  ParticleSystem
//
//  Created by Brenna Olson on 1/25/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100

let maxBuffersInFlight = 3
let floorVertexCount = 6

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {

    // MARK: - Metal Properties
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    var dynamicUniformBuffer: MTLBuffer
    var floorUniformBuffer: MTLBuffer
    var floorBuffer: MTLBuffer?
    
    /// Locations of all particles
    var particleVerticesBuffer: MTLBuffer?
    
    var spherePipelineState: MTLRenderPipelineState
    var floorPipelineState: MTLRenderPipelineState
    var particlesPipelineState: MTLRenderPipelineState
    
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture
    var fireworkTexture: MTLTexture
    var waterTexture: MTLTexture
    var fountainTexture: MTLTexture
    
    
    // MARK: - Buffer Properties
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    var uniformBufferOffset = 0
    var uniformBufferIndex = 0

    // separate values for sphere and float as the model matrices may vary
    var sphereUniforms: UnsafeMutablePointer<Uniforms>
    var floorUniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix = matrix_float4x4()
    var viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0)

    
    /// Sphere vertex data
    var sphereMesh: MTKMesh
    var fountainMesh: MTKMesh

    // can use for the texture coords - will be the same for all particles
    let unitSquareVertices = [float2(0, 0),
                              float2(0, 1),
                              float2(1, 1),
                              float2(0, 0),
                              float2(1, 1),
                              float2(1, 0)]
    
    
    /// Get a single square translated to a given location
    func getSquare(at origin: float3) -> [float3] {
        return [float3(origin.x, origin.y, origin.z),
                float3(origin.x, origin.y + 1, origin.z),
                float3(origin.x + 1, origin.y + 1, origin.z),
                float3(origin.x, origin.y, origin.z),
                float3(origin.x + 1, origin.y + 1, origin.z),
                float3(origin.x + 1, origin.y, origin.z)]
    }
    
    static var sphere = Particle(position: float3(0, 20, 0),
                                 velocity: float3(0, 0, 0),
                                 acceleration: float3(0.75, -9.8, 0),  // standard acceleration due to gravity
                                 radius: 1)
    
    /// Floor plane's location
    /// - note: This is exposed as a property so it can be detected when the sphere has come in contact with it
    private let floorY: Float = -8
    
    private var secondsElapsedSinceLastDrawCall = Date()
    
    /// Does a lot of the work of the particle system
    var particleSystem = ParticleSystem()
    
    // MARK: - Setup
    init?(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!

        // sphere uniforms buffer
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        dynamicUniformBuffer = device.makeBuffer(length:uniformBufferSize,
                                                           options:.storageModeShared)!
        
        // floor uniforms buffer
        floorUniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)!
        
        
        // floor buffer
        
        let floorXZ: Float = 45
        /// floor in x-z plane
        var floorVertices = [float3(-floorXZ, floorY, -floorXZ),    // far left
                             float3(-floorXZ, floorY, floorXZ),     // close left
                             float3(floorXZ, floorY, floorXZ),      // close right
                             float3(-floorXZ, floorY, -floorXZ),    // far left
                             float3(floorXZ, floorY, floorXZ),      // close right
                             float3(floorXZ, floorY, -floorXZ)]     // far right
        floorBuffer = device.makeBuffer(bytes: &floorVertices, length: MemoryLayout<float3>.stride * floorVertices.count, options: .storageModeShared)
        
        
        sphereUniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        floorUniforms = UnsafeMutableRawPointer(floorUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()

        
        
        // particle vertex buffer
        // because there's a max number of particles, this shouldn't need to be resized
        particleVerticesBuffer = device.makeBuffer(length: ParticleSystem.particleGenerationRate * ParticleSystem.particleLifespan * MemoryLayout<float2>.stride * 6, options: .storageModeShared)
        
        // pipeline states
        // sphere
        do {
            spherePipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
    
        // floor
        let library = device.makeDefaultLibrary()
        let vertexFloorFunction = library?.makeFunction(name: "vertexFloor")
        let fragmentFloorFunction = library?.makeFunction(name: "fragmentFloor")
        let floorRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        floorRenderPipelineDescriptor.vertexFunction = vertexFloorFunction
        floorRenderPipelineDescriptor.fragmentFunction = fragmentFloorFunction
        floorRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        floorRenderPipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        floorRenderPipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        
        do {
            try floorPipelineState = device.makeRenderPipelineState(descriptor: floorRenderPipelineDescriptor)
        } catch {
            print("Unable to set up floorPipelineState")
            return nil
        }
        
        let vertexParticlesFunction = library?.makeFunction(name: "vertexParticles")
        let fragmentParticlesFunction = library?.makeFunction(name: "fragmentShader")
        let particlesRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        particlesRenderPipelineDescriptor.vertexFunction = vertexParticlesFunction
        particlesRenderPipelineDescriptor.fragmentFunction = fragmentParticlesFunction
        particlesRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        particlesRenderPipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        particlesRenderPipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            try particlesPipelineState = device.makeRenderPipelineState(descriptor: particlesRenderPipelineDescriptor)
        } catch {
            print("Unable to set up particlesPipelineState")
            return nil
        }

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!

        do {
            sphereMesh = try Renderer.buildSphereMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        // fountain mesh
        let fountainMeshURL = URL(fileURLWithPath: "fountain.obj")
        let fountainMeshAsset = MDLAsset(url: fountainMeshURL)
        
        
        do {
            let meshes = try MTKMesh.newMeshes(asset: fountainMeshAsset, device: device)
            fountainMesh = meshes.metalKitMeshes[0]
        } catch {
            print("Unable to set up fountain mesh")
            return nil
        }
        
        

        do {
            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }
        
        do {
            fireworkTexture = try Renderer.loadTexture(device: device, textureName: "Firework")
            waterTexture = try Renderer.loadTexture(device: device, textureName: "Water")
            fountainTexture = try Renderer.loadTexture(device: device, textureName: "Fountain")
        } catch {
            print("Unable to load textures. Error info: \(error)")
            return nil
        }

        
        // attempting to get the ball inside the fov more
        Renderer.sphere.position.x = -30
        Renderer.sphere.position.y = 4
        Renderer.sphere.position.z = -30

        super.init()

    }

    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices

        let mtlVertexDescriptor = MTLVertexDescriptor()

        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }

    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let library = device.makeDefaultLibrary()

        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    
    /// Set up the vertices for a sphere
    class func buildSphereMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor

        let metalAllocator = MTKMeshBufferAllocator(device: device)

        
        let segmentCount = 30
        
        let sphereMesh = MDLMesh.newEllipsoid(withRadii: float3(Particle.radius, Particle.radius, Particle.radius), radialSegments: segmentCount, verticalSegments: segmentCount, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: metalAllocator)
        

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        sphereMesh.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:sphereMesh, device:device)
    }

    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)

    }

    
    // MARK: - Updates
    /// Update buffers containing uniform data such as matrices
    /// - note: Call `updateMatrices()` before calling this method
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        sphereUniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
        floorUniforms = UnsafeMutableRawPointer(floorUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }

    
    /// Update any movement of objects
    private func updateMatrices() {
        sphereUniforms[0].projectionMatrix = projectionMatrix
        floorUniforms[0].projectionMatrix = projectionMatrix
        
        var sphereModelMatrix = matrix_identity_float4x4
        let floorModelMatrix = matrix_identity_float4x4
        
        
        let positionUpdateAmount = secondsElapsedSinceLastDrawCall.timeIntervalSinceNow * -1

        
        // update physics
        // when the ball is going downward
        if Renderer.sphere.position.y > floorY + Particle.radius {
            Renderer.sphere.updatePosition(for: Float(positionUpdateAmount))
            
        // once the ball hits the ground
        } else {
            // the ball should be moving less both in the x and y directions as it hits the ground more times
            Renderer.sphere.velocity.x *= 0.7
            Renderer.sphere.velocity.y *= -0.85     // the ball has to reverse direction
            Renderer.sphere.updatePosition(for: Float(positionUpdateAmount))
        }
        
        if Renderer.sphere.position.y < floorY + Particle.radius {
            Renderer.sphere.position.y = floorY + Particle.radius
        }
        

        
        sphereModelMatrix[3] = float4(xyz: Renderer.sphere.position)

        
        sphereUniforms[0].modelViewMatrix = simd_mul(viewMatrix, sphereModelMatrix)
        floorUniforms[0].modelViewMatrix = simd_mul(viewMatrix, floorModelMatrix)
        
        // reset the timer to what's now the current number of seconds
        secondsElapsedSinceLastDrawCall = Date()
    }
    
    
    func updateParticleVerticesBuffer() {
        
    }

    
    // MARK: - MTKViewDelegate
    func draw(in view: MTKView) {
        /// Per frame updates hare

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            updateDynamicBufferState()
            updateMatrices()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                
                /// Final pass rendering code here
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    
                    // general setup
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setFrontFacing(.counterClockwise)
                    renderEncoder.setDepthStencilState(depthState)
                    
                    
                    // sphere
                    renderEncoder.setRenderPipelineState(spherePipelineState)
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    
                    for (index, element) in sphereMesh.vertexDescriptor.layouts.enumerated() {
                        guard let layout = element as? MDLVertexBufferLayout else {
                            return
                        }
                        
                        if layout.stride != 0 {
                            let buffer = sphereMesh.vertexBuffers[index]
                            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                        }
                    }
                    
                    renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
                    
                    for submesh in sphereMesh.submeshes {
                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                            indexCount: submesh.indexCount,
                                                            indexType: submesh.indexType,
                                                            indexBuffer: submesh.indexBuffer.buffer,
                                                            indexBufferOffset: submesh.indexBuffer.offset)
                    }
                    
                    
                    // floor
                    renderEncoder.setRenderPipelineState(floorPipelineState)
                    
                    renderEncoder.setVertexBuffer(floorBuffer, offset: 0, index: BufferIndex.floor.rawValue)
                    renderEncoder.setVertexBuffer(floorUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.floorUniforms.rawValue)
                    
                    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: floorVertexCount)

                    
                    // fountain
                    
                    
                    
                    // particles
                    renderEncoder.setRenderPipelineState(particlesPipelineState)
                    renderEncoder.setVertexBytes(unitSquareVertices, length: MemoryLayout<float2>.stride * 6, index: BufferIndex.particleTexCoords.rawValue)
                    renderEncoder.setVertexBuffer(particleVerticesBuffer, offset: 0, index: BufferIndex.particlePositions.rawValue)
                    
                    switch particleSystem.mode {
                    case .firework:
                        renderEncoder.setFragmentTexture(fireworkTexture, index: TextureIndex.color.rawValue)
                    case .water:
                        renderEncoder.setFragmentTexture(waterTexture, index: TextureIndex.color.rawValue)
                    }
                    
                    
                    
                    // ready to draw
                    renderEncoder.endEncoding()
                    
                    if let drawable = view.currentDrawable {
                        commandBuffer.present(drawable)
                    }
                }
            }
            
            commandBuffer.commit()
        }
    }

    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here

        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.001, farZ: 500.0)
    }
    
    // MARK: - Particle Setup
    /// For each new particle that's to be added
    func addParticle() {
        
    }
}
