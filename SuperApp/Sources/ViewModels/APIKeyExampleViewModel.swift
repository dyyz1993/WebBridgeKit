//
//  APIKeyExampleViewModel.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit
import WebBridgeKit

/// 代码示例模型
struct CodeExample {
    let title: String
    let language: String
    let code: String
    let description: String
}

/// API密钥使用示例 ViewModel
class APIKeyExampleViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let copyExample: Driver<Int>
    }

    struct Output {
        let examples: Driver<[CodeExample]>
        let copySuccess: Driver<Void>
        let copiedCode: Driver<String>
    }

    // MARK: - Properties

    private let examplesRelay = BehaviorRelay<[CodeExample]>(value: [])
    private let copySuccessRelay = PublishRelay<Void>()
    private let copiedCodeRelay = PublishRelay<String>()
    private static let serverBaseURL = "https://wbk.shanbox.19930810.xyz:8443"

    private let exampleData: [CodeExample] = [
        CodeExample(
            title: "Bark 推送请求",
            language: "URL",
            code: """
            https://wbk.shanbox.19930810.xyz:8443/YOUR_KEY_HERE/推送标题/推送内容?group=WebBridgeKit&sound=birdsong
            """,
            description: "使用 WebBridgeKit Bark 兼容 API 发送推送通知，支持自定义分组和铃声"
        ),
        CodeExample(
            title: "Swift 请求",
            language: "Swift",
            code: """
            import Alamofire

            let headers = ["Authorization": "Bearer YOUR_ADMIN_API_KEY"]
            AF.request("\(APIKeyExampleViewModel.serverBaseURL)/api/v1/manifests", headers: headers)
                .responseJSON { response in
                    // 处理响应
                }
            """,
            description: "使用 Alamofire 发送带管理 API Key 的请求"
        ),
        CodeExample(
            title: "cURL 请求",
            language: "Bash",
            code: """
            curl -H "Authorization: Bearer YOUR_ADMIN_API_KEY" \\
                 \(APIKeyExampleViewModel.serverBaseURL)/api/v1/manifests
            """,
            description: "使用 cURL 命令行工具发送请求"
        ),
        CodeExample(
            title: "JavaScript 请求",
            language: "JavaScript",
            code: """
            fetch('\(APIKeyExampleViewModel.serverBaseURL)/api/v1/manifests', {
              method: 'GET',
              headers: {
                'Authorization': 'Bearer YOUR_ADMIN_API_KEY',
                'Content-Type': 'application/json'
              }
            })
            .then(response => response.json())
            .then(data => console.log(data));
            """,
            description: "使用 JavaScript Fetch API 发送请求"
        ),
        CodeExample(
            title: "Python 请求",
            language: "Python",
            code: """
            import requests

            headers = {'Authorization': 'Bearer YOUR_ADMIN_API_KEY'}
            response = requests.get(
                '\(APIKeyExampleViewModel.serverBaseURL)/api/v1/manifests',
                headers=headers
            )

            # 处理响应
            data = response.json()
            """,
            description: "使用 Python requests 库发送请求"
        )
    ]

    // MARK: - Public Methods

    func example(at index: Int) -> CodeExample {
        return exampleData[index]
    }

    func numberOfExamples() -> Int {
        return exampleData.count
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 设置示例数据
        examplesRelay.accept(exampleData)

        // 处理复制操作
        input.copyExample
            .do(onNext: { [weak self] index in
                guard let self = self,
                      index >= 0 && index < self.exampleData.count else { return }
                let example = self.exampleData[index]
                self.copyToClipboard(example.code)
                self.copySuccessRelay.accept(())
                self.copiedCodeRelay.accept(example.code)
            })
            .drive()
            .disposed(by: rx)

        return Output(
            examples: examplesRelay.asDriver(),
            copySuccess: copySuccessRelay.asDriver(onErrorJustReturn: ()),
            copiedCode: copiedCodeRelay.asDriver(onErrorJustReturn: "")
        )
    }

    // MARK: - Private Methods

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}
