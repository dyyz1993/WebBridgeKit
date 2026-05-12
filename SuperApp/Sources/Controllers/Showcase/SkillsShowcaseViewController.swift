import UIKit
import WebBridgeKit
import SnapKit

class SkillsShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var skills: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, skills, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "技能"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadSkills()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SkillCell.self, forCellReuseIdentifier: "SkillCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadSkills() {
        skills = [
            ("1Password", "Password manager integration"),
            ("Stock Analysis", "A-share stock analysis"),
            ("Browser Agent", "Browser automation"),
            ("AI SDK", "AI capabilities"),
            ("Social Media", "Content creation"),
            ("Voice Cloning", "Text-to-speech"),
            ("Research", "Academic data search")
        ]
    }
}

extension SkillsShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .skills: return skills.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .skills: return "Built-in Skills (7)"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SkillCell", for: indexPath) as! SkillCell
            cell.configure(name: "Skills Module", description: "7 built-in skills extending framework capabilities for specialized tasks.")
            return cell

        case .skills:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SkillCell", for: indexPath) as! SkillCell
            let (name, description) = skills[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("Test Skill", .primary, { [weak self] in self?.testSkill() }),
                ("Load All Skills", .secondary, { [weak self] in self?.loadAllSkills() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class SkillCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.headline
        label.textColor = ThemeColors.current.text
        return label
    }()
    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
        nameLabel.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.bottom.equalToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, description: String) {
        nameLabel.text = name
        descLabel.text = description
    }
}

private class ActionCell: UITableViewCell {
    private let button = ThemeButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
            make.height.equalTo(40)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, style: ThemeButtonStyle, action: @escaping () -> Void) {
        button.configure(title: title, style: style)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }
}

extension SkillsShowcaseViewController {
    private func testSkill() {
        let alert = UIAlertController(title: "Skill Test", message: "Testing skill execution...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func loadAllSkills() {
        let alert = UIAlertController(title: "Skills", message: "All 7 skills loaded successfully:\n• 1Password\n• Stock Analysis\n• Browser Agent\n• AI SDK\n• Social Media\n• Voice Cloning\n• Research", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
