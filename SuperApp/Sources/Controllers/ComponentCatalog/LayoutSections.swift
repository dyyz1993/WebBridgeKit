//
//  LayoutSections.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 10: Gradient Views

    func buildGradientViewsSection() {
        let header = makeSectionHeader(
            title: "Gradient Views (ThemeGradientView)",
            tokenInfo: "ThemeGradientView — gradientStart → gradientEnd, diagonal direction"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_GradientViews"

        let smallGradient = ThemeGradientView()
        smallGradient.snp.makeConstraints { make in
            make.height.equalTo(60)
        }

        let largeGradient = ThemeGradientView()
        largeGradient.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        let stack = UIStackView(arrangedSubviews: [smallGradient, largeGradient])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(200)
        }
        addSection(header, container)
    }

    // MARK: - Section 11: Section Headers

    func buildSectionHeadersSection() {
        let header = makeSectionHeader(
            title: "Section Headers (ThemeSectionHeader)",
            tokenInfo: "ThemeSectionHeader — title + optional action button"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_SectionHeaders"
        container.backgroundColor = ThemeColors.current.surface
        container.layer.cornerRadius = ThemeCornerRadius.default.lg

        let withAction = ThemeSectionHeader()
        withAction.configure(title: "Recent Activity", actionTitle: "See All")

        let withoutAction = ThemeSectionHeader()
        withoutAction.configure(title: "Settings")

        let stack = UIStackView(arrangedSubviews: [withAction, withoutAction])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.md

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeSpacing.default.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(100)
        }
        addSection(header, container)
    }

    // MARK: - Section 12: Message Cells

    func buildMessageCellsSection() {
        let header = makeSectionHeader(
            title: "Message Cells (InboxMessageCell)",
            tokenInfo: "InboxMessageCell — unread dot, title, source, time, body preview"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_MessageCells"

        func createMessageCell(isUnread: Bool) -> UIView {
            let cell = UIView()
            cell.backgroundColor = ThemeColors.current.cardBackground
            cell.layer.cornerRadius = ThemeCornerRadius.default.lg

            let unreadDot = UIView()
            unreadDot.backgroundColor = ThemeTokens.Color.unreadDot
            unreadDot.layer.cornerRadius = ThemeTokens.CornerRadius.sm
            unreadDot.isHidden = !isUnread
            cell.addSubview(unreadDot)

            let titleLabel = UILabel()
            titleLabel.text = isUnread ? "New Feature Released" : "Weekly Digest"
            titleLabel.font = isUnread ? ThemeTokens.Typography.headline : ThemeTokens.Typography.callout
            titleLabel.textColor = ThemeColors.current.text
            cell.addSubview(titleLabel)

            let sourceLabel = UILabel()
            sourceLabel.text = "APNS"
            sourceLabel.font = ThemeTokens.Typography.caption2
            sourceLabel.textColor = ThemeColors.current.info

            let timeLabel = UILabel()
            timeLabel.text = "05-08 14:30"
            timeLabel.font = ThemeTokens.Typography.caption2
            timeLabel.textColor = ThemeTokens.Color.textTertiary
            timeLabel.textAlignment = .right
            cell.addSubview(timeLabel)

            let bodyLabel = UILabel()
            bodyLabel.text = "Check out the latest updates and improvements to your app experience..."
            bodyLabel.font = ThemeTokens.Typography.subheadline
            bodyLabel.textColor = ThemeColors.current.textSecondary
            bodyLabel.numberOfLines = 2
            cell.addSubview(bodyLabel)

            unreadDot.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(16)
                make.leading.equalToSuperview().offset(12)
                make.width.height.equalTo(10)
            }
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.leading.equalTo(unreadDot.snp.trailing).offset(8)
                make.trailing.equalToSuperview().offset(-12)
            }
            sourceLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(4)
                make.leading.equalTo(titleLabel)
            }
            timeLabel.snp.makeConstraints { make in
                make.centerY.equalTo(sourceLabel)
                make.trailing.equalToSuperview().offset(-12)
            }
            bodyLabel.snp.makeConstraints { make in
                make.top.equalTo(sourceLabel.snp.bottom).offset(6)
                make.leading.equalTo(titleLabel)
                make.trailing.equalToSuperview().offset(-12)
                make.bottom.equalToSuperview().offset(-12)
            }

            return cell
        }

        let unreadCell = createMessageCell(isUnread: true)
        unreadCell.snp.makeConstraints { make in
            make.height.equalTo(90)
        }

        let readCell = createMessageCell(isUnread: false)
        readCell.snp.makeConstraints { make in
            make.height.equalTo(90)
        }

        let stack = UIStackView(arrangedSubviews: [unreadCell, readCell])
        stack.axis = .vertical
        stack.spacing = ThemeSpacing.default.sm

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(200)
        }
        addSection(header, container)
    }
}
