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

// TODO: switch to release mode to test performance

class Renderer: NSObject, MTKViewDelegate {

    // MARK: - Metal Properties
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    var dynamicUniformBuffer: MTLBuffer
    var fountainTopUniformBuffer: MTLBuffer
    var fountainBottomUniformBuffer: MTLBuffer
    var floorUniformBuffer: MTLBuffer
    var floorBuffer: MTLBuffer?
    
    /// Locations of all particles
    var particleVerticesBuffer: MTLBuffer?
    
    var fountainPipelineState: MTLRenderPipelineState
    var floorPipelineState: MTLRenderPipelineState
    var waterParticlesPipelineState: MTLRenderPipelineState
    var fireworkParticlesPipelineState: MTLRenderPipelineState
    var fireworkParticlesPointsPipelineState: MTLRenderPipelineState
    
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
    var particleUniforms: UnsafeMutablePointer<Uniforms>
    var fountainTopUniforms: UnsafeMutablePointer<Uniforms>
    var fountainBottomUniforms: UnsafeMutablePointer<Uniforms>
    var floorUniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix = matrix_float4x4()
    var viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0)
    
    // separate out the view matrix transformations to make sure they're multiplied correctly later
    var viewMatrixRotation: Float = 0
    var viewMatrixTranslation = float2(0, 0)

    
    var fountainMeshTop: MTKMesh
    var fountainMeshBottom: MTKMesh

    // can use for the texture coords - will be the same for all particles
    let unitSquareVertices = [float2(0, 0),
                              float2(0, 1),
                              float2(1, 1),
                              float2(0, 0),
                              float2(1, 1),
                              float2(1, 0)]
    
    
    private var secondsElapsedSinceLastDrawCall = Date()
    
    /// Does a lot of the work of the particle system
    var particleSystem = ParticleSystem()
    
    // MARK: - Firework Color Changes
    var fireworkColor = float4(1, 0, 0, 1)
    var fireworkColorChangeState = ColorChangeState.RedConstantGreenUp
    let colorChangeAmountPerFrame: Float = 0.01
    var fireworkAsPoints = false
    
    
    // MARK: - Setup
    init?(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!

        // sphere uniforms buffer
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        dynamicUniformBuffer = device.makeBuffer(length:uniformBufferSize,
                                                           options:.storageModeShared)!
        
        // fountain uniforms buffers
        fountainTopUniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)!
        fountainBottomUniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)!
        
        // floor uniforms buffer
        floorUniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)!
        
        
        // floor buffer
        let floorXZ: Float = 45
        let floorY: Float = -8
        /// floor in x-z plane
        var floorVertices = [float3(-floorXZ, floorY, -floorXZ),    // far left
                             float3(-floorXZ, floorY, floorXZ),     // close left
                             float3(floorXZ, floorY, floorXZ),      // close right
                             float3(-floorXZ, floorY, -floorXZ),    // far left
                             float3(floorXZ, floorY, floorXZ),      // close right
                             float3(floorXZ, floorY, -floorXZ)]     // far right
        floorBuffer = device.makeBuffer(bytes: &floorVertices, length: MemoryLayout<float3>.stride * floorVertices.count, options: .storageModeShared)
        
        
        particleUniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        fountainTopUniforms = UnsafeMutableRawPointer(fountainTopUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
        fountainBottomUniforms = UnsafeMutableRawPointer(fountainBottomUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
        floorUniforms = UnsafeMutableRawPointer(floorUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()

        
        
        // particle vertex buffer
        // because there's a max number of particles, this shouldn't need to be resized
        particleVerticesBuffer = device.makeBuffer(length: 50000 * ParticleSystem.particleLifespan * MemoryLayout<float2>.stride * 6, options: .storageModeShared)
        
        // pipeline states
        // sphere
        do {
            fountainPipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
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
            try waterParticlesPipelineState = device.makeRenderPipelineState(descriptor: particlesRenderPipelineDescriptor)
        } catch {
            print("Unable to set up waterParticlesPipelineState")
            return nil
        }
        
        
        let fragmentFireworkParticlesFunction = library?.makeFunction(name: "fragmentFirework")
        let fireworkParticlesRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        fireworkParticlesRenderPipelineDescriptor.vertexFunction = vertexParticlesFunction
        fireworkParticlesRenderPipelineDescriptor.fragmentFunction = fragmentFireworkParticlesFunction
        fireworkParticlesRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        fireworkParticlesRenderPipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        fireworkParticlesRenderPipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            try fireworkParticlesPipelineState = device.makeRenderPipelineState(descriptor: fireworkParticlesRenderPipelineDescriptor)
        } catch {
            print("Unable to set up fireworkParticlesPipelineState")
            return nil
        }
        
        let vertexFireworkPointsFunction = library?.makeFunction(name: "vertexParticlesPoints")
        let fragmentFireworkPointsFunction = library?.makeFunction(name: "fragmentParticlesPoints")
        let fireworkPointsRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        fireworkPointsRenderPipelineDescriptor.vertexFunction = vertexFireworkPointsFunction
        fireworkPointsRenderPipelineDescriptor.fragmentFunction = fragmentFireworkPointsFunction
        fireworkPointsRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        fireworkPointsRenderPipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        fireworkPointsRenderPipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            try fireworkParticlesPointsPipelineState = device.makeRenderPipelineState(descriptor: fireworkPointsRenderPipelineDescriptor)
        } catch {
            print("Unable to set up fireworkPointsRenderPipelineState")
            return nil
        }
        

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!

        
        // fountain mesh
        
        let vertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            fountainMeshTop = try Renderer.buildCylinderMesh(device: device, mtlVertexDescriptor: vertexDescriptor, radius: 3, height: 2)
            fountainMeshBottom = try Renderer.buildCylinderMesh(device: device, mtlVertexDescriptor: vertexDescriptor, radius: 5, height: 2)
        } catch {
            print("Unable to set up fountain mesh pieces")
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
    class func buildCylinderMesh(device: MTLDevice,
                                 mtlVertexDescriptor: MTLVertexDescriptor, radius: Float, height: Float) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor

        let metalAllocator = MTKMeshBufferAllocator(device: device)

        
        let segmentCount = 30
        
        let cylinderMesh = MDLMesh.newCylinder(withHeight: height, radii: float2(radius, radius), radialSegments: segmentCount, verticalSegments: segmentCount, geometryType: .triangles, inwardNormals: false, allocator: metalAllocator)
        

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        cylinderMesh.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:cylinderMesh, device:device)
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

        particleUniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
        floorUniforms = UnsafeMutableRawPointer(floorUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
        fountainTopUniforms = UnsafeMutableRawPointer(fountainTopUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
        fountainBottomUniforms = UnsafeMutableRawPointer(fountainBottomUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }

    
    /// Update any movement of objects
    private func updateMatrices() {
        particleUniforms[0].projectionMatrix = projectionMatrix
        fountainTopUniforms[0].projectionMatrix = projectionMatrix
        fountainBottomUniforms[0].projectionMatrix = projectionMatrix
        floorUniforms[0].projectionMatrix = projectionMatrix
        
        var particleModelMatrix = matrix_identity_float4x4
        var fountainTopModelMatrix = matrix_identity_float4x4
        var fountainBottomModelMatrix = matrix_identity_float4x4
        let floorModelMatrix = matrix_identity_float4x4
        
        let mainTranslationMatrix = matrix4x4_translation(0.0, 0.0, -8.0)
        var particleViewMatrix = matrix_identity_float4x4
        
        let dt = secondsElapsedSinceLastDrawCall.timeIntervalSinceNow * -1


        // scaling
        let particleScale: Float
        
        // what size is best for each particle type varies
        switch particleSystem.mode {
        case .firework:
            particleScale = 0.04
        case .water:
            particleScale = 0.005
            // TODO: I think something needs to be updated in the particle model matrix for the initial y to be correct
            
        }
        
        
        particleModelMatrix[0][0] = particleScale
        particleModelMatrix[1][1] = particleScale
        
        if particleSystem.mode == .water {
            particleModelMatrix *= matrix4x4_translation(0, ParticleSystem.waterParticleStartY, 0)
        }
        
        let fountainScale: Float = 0.25
        
        fountainTopModelMatrix[0][0] = fountainScale
        fountainTopModelMatrix[1][1] = fountainScale
        fountainTopModelMatrix[2][2] = fountainScale
        fountainBottomModelMatrix[0][0] = fountainScale
        fountainBottomModelMatrix[1][1] = fountainScale
        fountainBottomModelMatrix[2][2] = fountainScale
        
        
        // translation
        fountainTopModelMatrix *= matrix4x4_translation(0, -6, 0)
        fountainBottomModelMatrix *= matrix4x4_translation(0, -8, 0)
        
        // TODO: particle-other object collision code goes here
        
        
        // view matrix
        let rotationMatrix = matrix4x4_rotation(radians: viewMatrixRotation, axis: float3(0, 1, 0))
        let rotationMatrixParticleSelf = matrix4x4_rotation(radians: viewMatrixRotation * -1, axis: float3(0, 1, 0))
        let translationMatrix = matrix4x4_translation(viewMatrixTranslation.x, 0, viewMatrixTranslation.z)
        
        viewMatrix = matrix_identity_float4x4
        viewMatrix *= rotationMatrix
        viewMatrix *= translationMatrix
        viewMatrix *= mainTranslationMatrix
        
        particleViewMatrix *= rotationMatrixParticleSelf
        particleViewMatrix *= rotationMatrix
        particleViewMatrix *= translationMatrix
        particleViewMatrix *= mainTranslationMatrix
        
        particleUniforms[0].modelViewMatrix = simd_mul(particleViewMatrix, particleModelMatrix)
        fountainTopUniforms[0].modelViewMatrix = simd_mul(viewMatrix, fountainTopModelMatrix)
        fountainBottomUniforms[0].modelViewMatrix = simd_mul(viewMatrix, fountainBottomModelMatrix)
        floorUniforms[0].modelViewMatrix = simd_mul(viewMatrix, floorModelMatrix)
        
        particleSystem.updateParticles(for: Float(dt))
        particleSystem.addParticles(for: Float(dt))
        
        // reset the timer to what's now the current number of seconds
        secondsElapsedSinceLastDrawCall = Date()
    }
    
    
    /// Store per-frame updates to particles
    func updateParticleVerticesBuffer() {
        for (index, particle) in particleSystem.allParticles.enumerated() {
            particleVerticesBuffer?.contents().storeBytes(of: particle.position, toByteOffset: MemoryLayout<float3>.stride * index, as: float3.self)
        }
    }
    
    
    /// As the firework particle color should change over time, this controls the changes to that color
    func updateFireworkColor() {
        switch fireworkColorChangeState {
        case .RedConstantGreenUp:
            fireworkColor.green += colorChangeAmountPerFrame
            
            if fireworkColor.green >= 1 {
                fireworkColorChangeState = .RedDownGreenConstant
            }
        case .RedDownGreenConstant:
            fireworkColor.red -= colorChangeAmountPerFrame
            
            if fireworkColor.red <= 0 {
                fireworkColorChangeState = .GreenConstantBlueUp
            }
        case .GreenConstantBlueUp:
            fireworkColor.blue += colorChangeAmountPerFrame
            
            if fireworkColor.blue >= 1 {
                fireworkColorChangeState = .GreenDownBlueConstant
            }
        case .GreenDownBlueConstant:
            fireworkColor.green -= colorChangeAmountPerFrame
            
            if fireworkColor.green <= 0 {
                fireworkColorChangeState = .BlueConstantRedUp
            }
        case .BlueConstantRedUp:
            fireworkColor.red += colorChangeAmountPerFrame
            
            if fireworkColor.red >= 1 {
                fireworkColorChangeState = .BlueDownRedConstant
            }
        case .BlueDownRedConstant:
            fireworkColor.blue -= colorChangeAmountPerFrame
            
            if fireworkColor.blue <= 0 {
                fireworkColorChangeState = .RedConstantGreenUp
            }
        }
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
            updateParticleVerticesBuffer()
            
            if particleSystem.mode == .firework {
                updateFireworkColor()
            }
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                
                /// Final pass rendering code here
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    
                    // general setup
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setFrontFacing(.counterClockwise)
                    renderEncoder.setDepthStencilState(depthState)
                    
                    
                    // floor
                    renderEncoder.setRenderPipelineState(floorPipelineState)
                    
                    renderEncoder.setVertexBuffer(floorBuffer, offset: 0, index: BufferIndex.floor.rawValue)
                    renderEncoder.setVertexBuffer(floorUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.floorUniforms.rawValue)
                    
                    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: floorVertexCount)

                    
                    // fountain - only want if simulating water
                    if particleSystem.mode == .water {
                        renderEncoder.setRenderPipelineState(fountainPipelineState)
                        
                        renderEncoder.setFragmentTexture(fountainTexture, index: TextureIndex.color.rawValue)
                        
                        
                        // bottom of fountain
                        renderEncoder.setVertexBuffer(fountainBottomUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                        
                        for (index, element) in fountainMeshBottom.vertexDescriptor.layouts.enumerated() {
                            guard let layout = element as? MDLVertexBufferLayout else {
                                return
                            }
                            
                            if layout.stride != 0 {
                                let buffer = fountainMeshBottom.vertexBuffers[index]
                                renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                            }
                        }
                    
                        
                        for submesh in fountainMeshBottom.submeshes {
                            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                                indexCount: submesh.indexCount,
                                                                indexType: submesh.indexType,
                                                                indexBuffer: submesh.indexBuffer.buffer,
                                                                indexBufferOffset: submesh.indexBuffer.offset)
                        }
                        
                        
                        // top of fountain
                        renderEncoder.setVertexBuffer(fountainTopUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                        
                        for (index, element) in fountainMeshTop.vertexDescriptor.layouts.enumerated() {
                            guard let layout = element as? MDLVertexBufferLayout else {
                                return
                            }
                            
                            if layout.stride != 0 {
                                let buffer = fountainMeshTop.vertexBuffers[index]
                                renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                            }
                        }
                        
                        
                        
                        for submesh in fountainMeshTop.submeshes {
                            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                                indexCount: submesh.indexCount,
                                                                indexType: submesh.indexType,
                                                                indexBuffer: submesh.indexBuffer.buffer,
                                                                indexBufferOffset: submesh.indexBuffer.offset)
                        }
                    }
                    
                    
                    // particles
                    // different between particle types
                    
                    // common between both particle types
                    renderEncoder.setVertexBytes(unitSquareVertices, length: MemoryLayout<float2>.stride * 6, index: BufferIndex.particleTexCoords.rawValue)
                    renderEncoder.setVertexBuffer(particleVerticesBuffer, offset: 0, index: BufferIndex.particlePositions.rawValue)
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    
                    switch particleSystem.mode {
                    case .firework:
                        renderEncoder.setFragmentBytes(&fireworkColor, length: MemoryLayout<float4>.stride, index: BufferIndex.fireworkColor.rawValue)
                        
                        if fireworkAsPoints == false {
                            renderEncoder.setRenderPipelineState(fireworkParticlesPipelineState)
                            
                            renderEncoder.setFragmentTexture(fireworkTexture, index: TextureIndex.color.rawValue)
                            
                            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: particleSystem.allParticles.count * 6)
                        } else {
                            renderEncoder.setRenderPipelineState(fireworkParticlesPointsPipelineState)
                            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleSystem.allParticles.count)
                        }
                        
                        
                    case .water:
                        renderEncoder.setRenderPipelineState(waterParticlesPipelineState)
                        renderEncoder.setFragmentTexture(waterTexture, index: TextureIndex.color.rawValue)
                        
                        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: particleSystem.allParticles.count * 6)
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
}
