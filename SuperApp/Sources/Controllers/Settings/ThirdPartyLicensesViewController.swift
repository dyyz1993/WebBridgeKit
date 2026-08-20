import UIKit
import WebBridgeKit

struct LicenseEntry {
    let name: String
    let version: String
    let licenseType: String
    let copyright: String
    let fullLicenseText: String
}

class ThirdPartyLicensesViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = ThemeTokens.Color.background
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "LicenseCell")
        tv.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        tv.accessibilityIdentifier = "licenses.tableView"
        return tv
    }()

    private let licenses: [LicenseEntry] = {
        let mit = [
            "MIT License",
            "",
            "Copyright (c) %@",
            "",
            "Permission is hereby granted, free of charge, to any person obtaining a copy",
            "of this software and associated documentation files (the \"Software\"), to deal",
            "in the Software without restriction, including without limitation the rights",
            "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell",
            "copies of the Software, and to permit persons to whom the Software is",
            "furnished to do so, subject to the following conditions:",
            "",
            "The above copyright notice and this permission notice shall be included in all",
            "copies or substantial portions of the Software.",
            "",
            "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR",
            "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,",
            "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE",
            "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER",
            "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,",
            "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE",
            "SOFTWARE."
        ].joined(separator: "\n")

        let apache = [
            "Apache License",
            "Version 2.0, January 2004",
            "http://www.apache.org/licenses/",
            "",
            "TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION",
            "",
            "1. Definitions.",
            "",
            "\"License\" shall mean the terms and conditions for use, reproduction,",
            "and distribution as defined by Sections 1 through 9 of this document.",
            "",
            "\"Licensor\" shall mean the copyright owner or entity authorized by",
            "the copyright owner that is granting the License.",
            "",
            "\"Legal Entity\" shall mean the union of the acting entity and all",
            "other entities that control, are controlled by, or are under common",
            "control with that entity.",
            "",
            "\"You\" (or \"Your\") shall mean an individual or Legal Entity",
            "exercising permissions granted by this License.",
            "",
            "\"Source\" form shall mean the preferred form for making modifications,",
            "including but not limited to software source code, documentation",
            "source, and configuration files.",
            "",
            "\"Object\" form shall mean any form resulting from mechanical",
            "transformation or translation of a Source form, including but",
            "not limited to compiled object code, generated documentation,",
            "and conversions to other media types.",
            "",
            "\"Work\" shall mean the work of authorship, whether in Source or",
            "Object form, made available under the License, as indicated by a",
            "copyright notice that is included in or attached to the work.",
            "",
            "\"Derivative Works\" shall mean any work, whether in Source or Object",
            "form, that is based on (or derived from) the Work and for which the",
            "editorial revisions, annotations, elaborations, or other modifications",
            "represent, as a whole, an original work of authorship.",
            "",
            "\"Contribution\" shall mean any work of authorship, including",
            "the original version of the Work and any modifications or additions",
            "to that Work or Derivative Works thereof, that is intentionally",
            "submitted to the Licensor for inclusion in the Work by the copyright",
            "owner or by an individual or Legal Entity authorized to submit on",
            "behalf of the copyright owner.",
            "",
            "\"Contributor\" shall mean Licensor and any individual or Legal Entity",
            "on behalf of whom a Contribution has been received by the Licensor and",
            "subsequently incorporated within the Work.",
            "",
            "2. Grant of Copyright License. Subject to the terms and conditions of",
            "this License, each Contributor hereby grants to You a perpetual,",
            "worldwide, non-exclusive, no-charge, royalty-free, irrevocable",
            "copyright license to reproduce, prepare Derivative Works of,",
            "publicly display, publicly perform, sublicense, and distribute the",
            "Work and such Derivative Works in Source or Object form.",
            "",
            "3. Grant of Patent License. Subject to the terms and conditions of",
            "this License, each Contributor hereby grants to You a perpetual,",
            "worldwide, non-exclusive, no-charge, royalty-free, irrevocable",
            "(except as stated in this section) patent license to make, have made,",
            "use, offer to sell, sell, import, and otherwise transfer the Work,",
            "where such license applies only to those patent claims licensable",
            "by such Contributor that are necessarily infringed by their",
            "Contribution(s) alone or by combination of their Contribution(s)",
            "with the Work to which such Contribution(s) was submitted.",
            "",
            "4. Redistribution. You may reproduce and distribute copies of the",
            "Work or Derivative Works thereof in any medium, with or without",
            "modifications, and in Source or Object form, provided that You",
            "meet the following conditions:",
            "",
            "(a) You must give any other recipients of the Work or",
            "    Derivative Works a copy of this License; and",
            "",
            "(b) You must cause any modified files to carry prominent notices",
            "    stating that You changed the files; and",
            "",
            "(c) You must retain, in the Source form of any Derivative Works",
            "    that You distribute, all copyright, patent, trademark, and",
            "    attribution notices from the Source form of the Work,",
            "    excluding those notices that do not pertain to any part of",
            "    the Derivative Works; and",
            "",
            "(d) If the Work includes a \"NOTICE\" text file as part of its",
            "    distribution, then any Derivative Works that You distribute must",
            "    include a readable copy of the attribution notices contained",
            "    within such NOTICE file.",
            "",
            "You may add Your own copyright statement to Your modifications and",
            "may provide additional or different license terms and conditions",
            "for use, reproduction, or distribution of Your modifications, or",
            "for any such Derivative Works as a whole, provided Your use,",
            "reproduction, and distribution of the Work otherwise complies with",
            "the conditions stated in this License.",
            "",
            "5. Submission of Contributions. Unless You explicitly state otherwise,",
            "any Contribution intentionally submitted for inclusion in the Work",
            "by You to the Licensor shall be under the terms and conditions of",
            "this License, without any additional terms or conditions.",
            "",
            "6. Trademarks. This License does not grant permission to use the trade",
            "names, trademarks, service marks, or product names of the Licensor,",
            "except as required for reasonable and customary use in describing the",
            "origin of the Work and reproducing the content of the NOTICE file.",
            "",
            "7. Disclaimer of Warranty. Unless required by applicable law or",
            "agreed to in writing, Licensor provides the Work (and each",
            "Contributor provides its Contributions) on an \"AS IS\" BASIS,",
            "WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or",
            "implied, including, without limitation, any warranties or conditions",
            "of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A",
            "PARTICULAR PURPOSE.",
            "",
            "8. Limitation of Liability. In no event and under no legal theory,",
            "whether in tort (including negligence), contract, or otherwise,",
            "unless required by applicable law or agreed to in writing, shall any",
            "Contributor be liable to You for damages, including any direct,",
            "indirect, special, incidental, or consequential damages of any",
            "character arising as a result of this License or out of the use or",
            "inability to use the Work.",
            "",
            "9. Accepting Warranty or Additional Liability. While redistributing",
            "the Work or Derivative Works thereof, You may choose to offer,",
            "and charge a fee for, acceptance of support, warranty, indemnity,",
            "or other liability obligations and/or rights consistent with this",
            "License.",
            "",
            "END OF TERMS AND CONDITIONS",
            "",
            "Copyright 2020 MongoDB, Inc.",
            "",
            "Licensed under the Apache License, Version 2.0 (the \"License\");",
            "you may not use this file except in compliance with the License.",
            "You may obtain a copy of the License at",
            "",
            "    http://www.apache.org/licenses/LICENSE-2.0",
            "",
            "Unless required by applicable law or agreed to in writing, software",
            "distributed under the License is distributed on an \"AS IS\" BASIS,",
            "WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
            "See the License for the specific language governing permissions and",
            "limitations under the License."
        ].joined(separator: "\n")

        func mitFor(_ holder: String) -> String {
            String(format: mit, holder)
        }

        return [
            LicenseEntry(name: "Alamofire", version: "5.11.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Alamofire Software Foundation",
                         fullLicenseText: mitFor("2024 Alamofire Software Foundation")),
            LicenseEntry(name: "Differentiator", version: "5.0.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2020 RxSwift Community",
                         fullLicenseText: mitFor("2020 RxSwift Community")),
            LicenseEntry(name: "Kingfisher", version: "7.12.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Wei Wang",
                         fullLicenseText: mitFor("2024 Wei Wang")),
            LicenseEntry(name: "Moya", version: "15.0.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Ash Furrow",
                         fullLicenseText: mitFor("2024 Ash Furrow")),
            LicenseEntry(name: "Realm", version: "10.54.6", licenseType: "Apache 2.0",
                         copyright: "Copyright 2020 MongoDB, Inc.",
                         fullLicenseText: apache),
            LicenseEntry(name: "RealmSwift", version: "10.54.6", licenseType: "Apache 2.0",
                         copyright: "Copyright 2020 MongoDB, Inc.",
                         fullLicenseText: apache),
            LicenseEntry(name: "RxCocoa", version: "6.9.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Krunoslav Zaher",
                         fullLicenseText: mitFor("2024 Krunoslav Zaher")),
            LicenseEntry(name: "RxDataSources", version: "5.0.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2020 RxSwift Community",
                         fullLicenseText: mitFor("2020 RxSwift Community")),
            LicenseEntry(name: "RxRelay", version: "6.9.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Krunoslav Zaher",
                         fullLicenseText: mitFor("2024 Krunoslav Zaher")),
            LicenseEntry(name: "RxSwift", version: "6.9.0", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Krunoslav Zaher",
                         fullLicenseText: mitFor("2024 Krunoslav Zaher")),
            LicenseEntry(name: "SnapKit", version: "5.7.1", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 SnapKit Team",
                         fullLicenseText: mitFor("2024 SnapKit Team")),
            LicenseEntry(name: "SwiftSoup", version: "2.11.3", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Nabil Chatbi",
                         fullLicenseText: mitFor("2024 Nabil Chatbi")),
            LicenseEntry(name: "ZIPFoundation", version: "0.9.20", licenseType: "MIT",
                         copyright: "Copyright (c) 2024 Thomas Zoechling",
                         fullLicenseText: mitFor("2024 Thomas Zoechling"))
        ]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("about.third_party_licenses")
        view.backgroundColor = ThemeTokens.Color.background
        view.accessibilityIdentifier = "licenses.root"

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension ThirdPartyLicensesViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return licenses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LicenseCell", for: indexPath)
        let entry = licenses[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = "\(entry.name)  \(entry.version)"
        content.textProperties.font = ThemeTokens.Typography.callout
        content.textProperties.color = ThemeTokens.Color.text

        content.secondaryText = "\(entry.licenseType)  ·  \(entry.copyright)"
        content.secondaryTextProperties.font = ThemeTokens.Typography.caption1
        content.secondaryTextProperties.color = ThemeTokens.Color.textSecondary
        content.secondaryTextProperties.numberOfLines = 1

        if let icon = LucideIcon.docText.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) {
            content.image = icon
            content.imageProperties.tintColor = ThemeTokens.Color.primary
            content.imageProperties.maximumSize = CGSize(width: ThemeTokens.Icons.Sizes.md, height: ThemeTokens.Icons.Sizes.md)
        }

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ThemeTokens.Color.cardBackground
        cell.accessibilityIdentifier = "licenses.cell.\(entry.accessibilityKey)"

        return cell
    }
}

private extension LicenseEntry {
    var accessibilityKey: String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: ".", with: "-")
    }
}

extension ThirdPartyLicensesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = licenses[indexPath.row]
        let detailVC = LicenseDetailViewController(entry: entry)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
