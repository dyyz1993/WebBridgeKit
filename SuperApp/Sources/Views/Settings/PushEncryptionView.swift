import SwiftUI
import CryptoKit
import WebBridgeKit

/// Encryption key management for end-to-end encrypted push messages.
/// Generates a symmetric AES-128 key stored in the keychain (shared with
/// the NSE via the same keychain access group). The user shares this key
/// with the sender out-of-band; the sender encrypts payloads with AES-GCM.
struct PushEncryptionView: View {
    @State private var keyBase64: String = ""
    @State private var showingShareSheet = false

    var body: some View {
        List {
            Section(header: Text("推送加密密钥")) {
                if keyBase64.isEmpty {
                    Button {
                        generateKey()
                    } label: {
                        HStack {
                            Image(uiImage: LucideIcon.key.templateImage(pointSize: 20) ?? UIImage())
                                .renderingMode(.template)
                                .foregroundColor(Color.appPrimary)
                            Text("生成加密密钥")
                                .font(Font.app(ThemeTokens.Typography.rowTitle))
                        }
                        .padding(.vertical, ThemeTokens.Spacing.sm)
                    }
                    .buttonStyle(.borderless)
                    Text("生成后，将密钥分享给发送方。发送方使用 AES-128-GCM 加密推送内容，本机自动解密。")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                } else {
                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                        Text("当前密钥")
                            .font(Font.app(ThemeTokens.Typography.metadata))
                            .foregroundColor(Color.appTextSecondary)
                        Text(keyBase64)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.appText)
                            
                            .padding(ThemeTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(ThemeTokens.Color.surfaceElevated))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                        HStack(spacing: ThemeTokens.Spacing.sm) {
                            actionButton(title: "复制密钥", icon: LucideIcon.copy) {
                                UIPasteboard.general.string = keyBase64
                                HUDService.shared.showSuccess(withStatus: "密钥已复制")
                            }
                        }
                    }
                    .padding(.vertical, ThemeTokens.Spacing.sm)
                }
            }

            Section(header: Text("使用方法")) {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                    usageRow(number: "1", text: "生成密钥并分享给发送方")
                    usageRow(number: "2", text: "发送方用此密钥 AES-128-GCM 加密推送 JSON")
                    usageRow(number: "3", text: "发送 URL 附带 ?ciphertext=<base64>")
                    usageRow(number: "4", text: "本机 NSE 自动解密并展示原始内容")
                }
                .padding(.vertical, ThemeTokens.Spacing.sm)
            }
        }
        .appListStyle()
        .navigationTitle("推送加密")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadKey)
    }

    private func usageRow(number: String, text: String) -> some View {
        HStack(spacing: ThemeTokens.Spacing.sm) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.appPrimary)
                .frame(width: 20, height: 20)
                .background(Color(ThemeTokens.Color.primarySoft))
                .clipShape(Circle())
            Text(text)
                .font(Font.app(ThemeTokens.Typography.footnote))
                .foregroundColor(Color.appText)
        }
    }

    private func actionButton(title: String, icon: LucideIcon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                Image(uiImage: icon.templateImage(pointSize: 16) ?? UIImage())
                    .renderingMode(.template)
                Text(title)
                    .font(Font.app(ThemeTokens.Typography.subheadline))
            }
            .padding(.horizontal, ThemeTokens.Spacing.md)
            .padding(.vertical, ThemeTokens.Spacing.sm)
            .background(Color(ThemeTokens.Color.primarySoft))
            .foregroundColor(Color.appPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
    }

    private func loadKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.webbridgekit.superapp.push-crypto",
            kSecAttrAccount as String: "shared-aes-key",
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            keyBase64 = data.base64EncodedString()
        }
    }

    private func generateKey() {
        let key = SymmetricKey(size: .bits128)
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.webbridgekit.superapp.push-crypto",
            kSecAttrAccount as String: "shared-aes-key",
            kSecValueData as String: keyData,
        ]
        SecItemDelete(query as CFDictionary)
        if SecItemAdd(query as CFDictionary, nil) == errSecSuccess {
            keyBase64 = keyData.base64EncodedString()
            HUDService.shared.showSuccess(withStatus: "密钥已生成")
        }
    }
}
