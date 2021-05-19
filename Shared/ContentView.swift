//
//  ContentView.swift
//  Shared
//
//  Created by Craig on 2021/5/16.
//

import SwiftUI
import Metal
import MetalKit

extension MTLBuffer {
    func generateRandomFloatData(){
        let dataPtr = self.contents()
        for index in 0...self.length {
            let rand: Float32 = Float32(arc4random())/Float32(RAND_MAX)
            (dataPtr + index * 4).storeBytes(of: rand, as: Float32.self)
        }
    }
}

func getArray<T>(address p: UnsafeMutableRawPointer, as type: T.Type, length arrayLength: Int) -> [T] {
    let typedPtr = p.bindMemory(to: type, capacity: arrayLength)
    let bufferPointer = UnsafeBufferPointer<T>(start: typedPtr, count: arrayLength)
    return Array(bufferPointer)
}

func initMetal(_ arrayLength: Int) -> [[Float32]]? {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return nil;
    }
    guard let library = device.makeDefaultLibrary() else {
        return nil;
    }
    guard let adder = library.makeFunction(name: "add_arrays") else {return nil}
    
    guard let addFunctionPso = try? device.makeComputePipelineState(function: adder) else { return nil }
    
    guard let commandQueue = device.makeCommandQueue() else { return nil }
    
    if let bufferA = device.makeBuffer(length: arrayLength, options: .storageModeShared),
       let bufferB = device.makeBuffer(length: arrayLength, options: .storageModeShared),
       let bufferResult = device.makeBuffer(length: arrayLength, options: .storageModeShared) {
        
        bufferA.generateRandomFloatData()
        bufferB.generateRandomFloatData()
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        computeEncoder.setComputePipelineState(addFunctionPso)
        computeEncoder.setBuffer(bufferA, offset: 0, index: 0)
        computeEncoder.setBuffer(bufferB, offset: 0, index: 1)
        computeEncoder.setBuffer(bufferResult, offset: 0, index: 2)
        
        let gridSize = MTLSizeMake(arrayLength, 1, 1)
        let threadGroupSize = min(addFunctionPso.maxTotalThreadsPerThreadgroup, arrayLength)
        let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        
        return [getArray(address: bufferA.contents(), as: Float32.self, length: arrayLength),
                getArray(address: bufferB.contents(), as: Float32.self, length: arrayLength),
                getArray(address: bufferResult.contents(), as: Float32.self, length: arrayLength)]
    }
    return nil
}

struct ContentView: View {
    let arrayLength = 10
    var body: some View {
        List(0..<arrayLength, id: \.self) { id in
            if let calc = initMetal(arrayLength) {
                Text("\(calc[0][id]) + \(calc[1][id]) => GPU: \(calc[2][id]), CPU: \(calc[0][id] + calc[1][id])")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
