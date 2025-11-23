//
//  ModelDownloadManager.swift
//  OS One
//
//  Handles downloading and caching of local LLM models
//  Supports HuggingFace model repository downloads
//

import Foundation
import Combine

// MARK: - Model Download Manager
class ModelDownloadManager: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var downloadProgress: [String: Float] = [:]
    @Published var downloadState: [String: DownloadState] = [:]
    @Published var errorMessages: [String: String] = [:]

    // MARK: - Download State
    enum DownloadState {
        case notStarted
        case downloading
        case paused
        case completed
        case failed
    }

    // MARK: - Properties
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let modelsDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - HuggingFace Configuration
    private let huggingFaceBaseURL = "https://huggingface.co"
    private var huggingFaceToken: String? {
        UserDefaults.standard.string(forKey: "huggingFaceToken")
    }

    // MARK: - Required Files for Each Model
    private let requiredModelFiles = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "model.safetensors",
        "generation_config.json"
    ]

    // MARK: - Initialization
    override init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        modelsDirectory = documentsPath.appendingPathComponent("LocalModels")

        super.init()

        // Create models directory if it doesn't exist
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        print("ModelDownloadManager: Initialized with directory: \(modelsDirectory.path)")
    }

    // MARK: - Download Model
    func downloadModel(_ modelType: LocalModelType, completion: @escaping (Result<URL, Error>) -> Void) {
        let modelName = modelType.rawValue
        let modelPath = modelsDirectory.appendingPathComponent(modelName)

        print("ModelDownloadManager: Starting download for \(modelType.displayName)")

        // Create model directory
        try? fileManager.createDirectory(at: modelPath, withIntermediateDirectories: true)

        // Update state
        DispatchQueue.main.async {
            self.downloadState[modelName] = .downloading
            self.downloadProgress[modelName] = 0.0
        }

        // Download all required files
        let dispatchGroup = DispatchGroup()
        var downloadErrors: [Error] = []

        for filename in requiredModelFiles {
            dispatchGroup.enter()

            downloadFile(
                modelRepo: modelName,
                filename: filename,
                destination: modelPath
            ) { result in
                switch result {
                case .success:
                    print("ModelDownloadManager: Downloaded \(filename)")
                case .failure(let error):
                    print("ModelDownloadManager: Failed to download \(filename): \(error)")
                    downloadErrors.append(error)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if downloadErrors.isEmpty {
                self.downloadState[modelName] = .completed
                self.downloadProgress[modelName] = 1.0
                print("ModelDownloadManager: Model \(modelType.displayName) downloaded successfully")
                completion(.success(modelPath))
            } else {
                self.downloadState[modelName] = .failed
                let error = ModelDownloadError.downloadFailed("Failed to download some model files")
                self.errorMessages[modelName] = error.localizedDescription
                completion(.failure(error))
            }
        }
    }

    // MARK: - Download Individual File
    private func downloadFile(modelRepo: String, filename: String, destination: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Construct HuggingFace URL
        // Format: https://huggingface.co/{repo}/resolve/main/{filename}
        let urlString = "\(huggingFaceBaseURL)/\(modelRepo)/resolve/main/\(filename)"

        guard let url = URL(string: urlString) else {
            completion(.failure(ModelDownloadError.invalidURL(urlString)))
            return
        }

        var request = URLRequest(url: url)

        // Add authorization header if token is available
        if let token = huggingFaceToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let destinationPath = destination.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: destinationPath.path) {
            print("ModelDownloadManager: File \(filename) already exists, skipping")
            completion(.success(destinationPath))
            return
        }

        // Start download task
        let downloadTask = urlSession.downloadTask(with: request) { tempURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let tempURL = tempURL else {
                completion(.failure(ModelDownloadError.downloadFailed("No file downloaded")))
                return
            }

            do {
                // Move downloaded file to destination
                if self.fileManager.fileExists(atPath: destinationPath.path) {
                    try self.fileManager.removeItem(at: destinationPath)
                }
                try self.fileManager.moveItem(at: tempURL, to: destinationPath)
                completion(.success(destinationPath))
            } catch {
                completion(.failure(error))
            }
        }

        let taskKey = "\(modelRepo)_\(filename)"
        downloadTasks[taskKey] = downloadTask
        downloadTask.resume()
    }

    // MARK: - Convert to MLX Format
    func convertToMLXFormat(_ modelType: LocalModelType) async throws {
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

        print("ModelDownloadManager: Converting \(modelType.displayName) to MLX format...")

        // This would typically involve:
        // 1. Loading the safetensors weights
        // 2. Converting them to MLX format
        // 3. Saving as optimized MLX weights

        // For now, we'll assume the safetensors can be loaded directly by MLX
        // In production, you might want to run a Python script to do the conversion

        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate conversion time

        print("ModelDownloadManager: Conversion complete")
    }

    // MARK: - Model Management
    func deleteModel(_ modelType: LocalModelType) throws {
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

        if fileManager.fileExists(atPath: modelPath.path) {
            try fileManager.removeItem(at: modelPath)
            print("ModelDownloadManager: Deleted model \(modelType.displayName)")

            DispatchQueue.main.async {
                self.downloadState[modelType.rawValue] = .notStarted
                self.downloadProgress[modelType.rawValue] = 0.0
            }
        }
    }

    func isModelDownloaded(_ modelType: LocalModelType) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

        // Check if all required files exist
        for filename in requiredModelFiles {
            let filePath = modelPath.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: filePath.path) {
                return false
            }
        }

        return true
    }

    func getModelSize(_ modelType: LocalModelType) -> UInt64 {
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

        do {
            return try fileManager.allocatedSizeOfDirectory(at: modelPath)
        } catch {
            return 0
        }
    }

    func getAvailableModels() -> [LocalModelType] {
        return LocalModelType.allCases.filter { isModelDownloaded($0) }
    }

    func getTotalModelsSize() -> UInt64 {
        var totalSize: UInt64 = 0

        for modelType in LocalModelType.allCases {
            totalSize += getModelSize(modelType)
        }

        return totalSize
    }

    // MARK: - Download Control
    func pauseDownload(_ modelType: LocalModelType) {
        let modelName = modelType.rawValue

        for (key, task) in downloadTasks where key.hasPrefix(modelName) {
            task.suspend()
        }

        DispatchQueue.main.async {
            self.downloadState[modelName] = .paused
        }

        print("ModelDownloadManager: Paused download for \(modelType.displayName)")
    }

    func resumeDownload(_ modelType: LocalModelType) {
        let modelName = modelType.rawValue

        for (key, task) in downloadTasks where key.hasPrefix(modelName) {
            task.resume()
        }

        DispatchQueue.main.async {
            self.downloadState[modelName] = .downloading
        }

        print("ModelDownloadManager: Resumed download for \(modelType.displayName)")
    }

    func cancelDownload(_ modelType: LocalModelType) {
        let modelName = modelType.rawValue

        for (key, task) in downloadTasks where key.hasPrefix(modelName) {
            task.cancel()
            downloadTasks.removeValue(forKey: key)
        }

        DispatchQueue.main.async {
            self.downloadState[modelName] = .notStarted
            self.downloadProgress[modelName] = 0.0
        }

        // Clean up partial downloads
        let modelPath = modelsDirectory.appendingPathComponent(modelName)
        try? fileManager.removeItem(at: modelPath)

        print("ModelDownloadManager: Cancelled download for \(modelType.displayName)")
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in completion block
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

        // Extract model name from task description
        if let url = downloadTask.originalRequest?.url?.absoluteString,
           let modelName = extractModelName(from: url) {

            DispatchQueue.main.async {
                // Update overall model progress (average of all file downloads)
                if let currentProgress = self.downloadProgress[modelName] {
                    self.downloadProgress[modelName] = (currentProgress + progress) / 2.0
                } else {
                    self.downloadProgress[modelName] = progress
                }
            }
        }
    }

    private func extractModelName(from urlString: String) -> String? {
        // Extract model name from HuggingFace URL
        // Format: https://huggingface.co/{repo}/resolve/main/{filename}
        let components = urlString.components(separatedBy: "/")
        if components.count >= 5 {
            let repo = components[3] + "/" + components[4]
            return repo
        }
        return nil
    }
}

// MARK: - Errors
enum ModelDownloadError: LocalizedError {
    case invalidURL(String)
    case downloadFailed(String)
    case conversionFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .conversionFailed(let message):
            return "Model conversion failed: \(message)"
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        }
    }
}
