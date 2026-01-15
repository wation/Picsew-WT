import UIKit
import MessageUI
import StoreKit

class SettingsViewController: UIViewController {
    
    private let viewModel = SettingsViewModel()
    
    // MARK: - UI 组件
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let versionLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("version_info", comment: "Version info")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.shadowColor = UIColor(white: 0, alpha: 0.1)
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        title = NSLocalizedString("settings", comment: "Settings")
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(versionLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: versionLabel.topAnchor, constant: -10),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
        
        setupCards()
    }
    
    private func setupCards() {
        contentView.addArrangedSubview(createExportSettingsCard())
        contentView.addArrangedSubview(createScrollSettingsCard())
        contentView.addArrangedSubview(createGeneralFunctionsCard())
    }
    
    @objc private func formatFieldTapped(_ gesture: UITapGestureRecognizer) {
        guard let fieldView = gesture.view else { return }
        
        let alert = UIAlertController(title: NSLocalizedString("select_image_format", comment: "Select image format"), message: nil, preferredStyle: .actionSheet)
        
        for format in ImageFormat.allCases {
            let action = UIAlertAction(title: format.rawValue, style: .default) { [weak self] _ in
                self?.viewModel.selectedFormat = format
                // 更新 UI
                if let valueLabel = fieldView.viewWithTag(100) as? UILabel {
                    valueLabel.text = format.rawValue
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = fieldView
            popover.sourceRect = fieldView.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func resolutionFieldTapped(_ gesture: UITapGestureRecognizer) {
        guard let fieldView = gesture.view else { return }
        
        let alert = UIAlertController(title: NSLocalizedString("select_resolution", comment: "Select resolution"), message: nil, preferredStyle: .actionSheet)
        
        for res in Resolution.allCases {
            let action = UIAlertAction(title: res.localizedString, style: .default) { [weak self] _ in
                self?.viewModel.selectedResolution = res
                // 更新 UI
                if let valueLabel = fieldView.viewWithTag(100) as? UILabel {
                    valueLabel.text = res.localizedString
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = fieldView
            popover.sourceRect = fieldView.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func stopDurationFieldTapped(_ gesture: UITapGestureRecognizer) {
        guard let fieldView = gesture.view else { return }
        
        let alert = UIAlertController(title: NSLocalizedString("select_auto_stop_duration", comment: "Select auto stop duration"), message: nil, preferredStyle: .actionSheet)
        
        for duration in StopDuration.allCases {
            let action = UIAlertAction(title: duration.localizedString, style: .default) { [weak self] _ in
                self?.viewModel.selectedStopDuration = duration
                // 更新 UI
                if let valueLabel = fieldView.viewWithTag(100) as? UILabel {
                    valueLabel.text = duration.localizedString
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = fieldView
            popover.sourceRect = fieldView.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - 卡片创建方法
    
    private func createCardContainer() -> UIView {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }
    
    private func createHeaderView(icon: String, title: String) -> UIView {
        let view = UIView()
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(iconView)
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            view.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        let line = UIView()
        line.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        line.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return view
    }
    
    private func createDropdownField(title: String, value: String, action: Selector? = nil) -> UIView {
        let view = UIView()
        if let action = action {
            let tap = UITapGestureRecognizer(target: self, action: action)
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
        }
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let dropdownView = UIView()
        dropdownView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        dropdownView.layer.cornerRadius = 8
        dropdownView.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.tag = 100 // 用于后续查找和更新
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let arrowIcon = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrowIcon.tintColor = .systemGray3
        arrowIcon.contentMode = .scaleAspectFit
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false
        
        dropdownView.addSubview(valueLabel)
        dropdownView.addSubview(arrowIcon)
        view.addSubview(titleLabel)
        view.addSubview(dropdownView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            dropdownView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            dropdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dropdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dropdownView.heightAnchor.constraint(equalToConstant: 44),
            dropdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            
            valueLabel.leadingAnchor.constraint(equalTo: dropdownView.leadingAnchor, constant: 12),
            valueLabel.centerYAnchor.constraint(equalTo: dropdownView.centerYAnchor),
            
            arrowIcon.trailingAnchor.constraint(equalTo: dropdownView.trailingAnchor, constant: -12),
            arrowIcon.centerYAnchor.constraint(equalTo: dropdownView.centerYAnchor),
            arrowIcon.widthAnchor.constraint(equalToConstant: 14),
            arrowIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        return view
    }
    
    private func createExportSettingsCard() -> UIView {
        let card = createCardContainer()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        stack.addArrangedSubview(createHeaderView(icon: "doc.text.image", title: NSLocalizedString("export_settings_header", comment: "Export settings header")))
        
        let formatField = createDropdownField(title: NSLocalizedString("image_format", comment: "Image format"), value: viewModel.selectedFormat.rawValue, action: #selector(formatFieldTapped))
        stack.addArrangedSubview(formatField)
        
        let resolutionField = createDropdownField(title: NSLocalizedString("resolution", comment: "Resolution"), value: viewModel.selectedResolution.localizedString, action: #selector(resolutionFieldTapped))
        stack.addArrangedSubview(resolutionField)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        
        return card
    }
    
    private func createScrollSettingsCard() -> UIView {
        let card = createCardContainer()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        stack.addArrangedSubview(createHeaderView(icon: "clock", title: NSLocalizedString("scroll_settings_header", comment: "Scroll settings header")))
        
        let durationField = createDropdownField(title: NSLocalizedString("auto_stop_duration", comment: "Auto stop duration"), value: viewModel.selectedStopDuration.localizedString, action: #selector(stopDurationFieldTapped))
        stack.addArrangedSubview(durationField)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        
        return card
    }
    
    private func createGeneralFunctionsCard() -> UIView {
        let card = createCardContainer()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        let items = [
            (icon: "envelope.fill", title: NSLocalizedString("contact_us", comment: "Contact us"), showArrow: true, showStars: false, action: #selector(contactUsTapped)),
            (icon: "star.fill", title: NSLocalizedString("rate_app_store", comment: "Rate app store"), showArrow: false, showStars: true, action: #selector(rateAppTapped)),
            (icon: "square.and.arrow.up", title: NSLocalizedString("recommend_friends", comment: "Recommend friends"), showArrow: false, showStars: false, action: #selector(recommendFriendsTapped))
        ]
        
        for (index, item) in items.enumerated() {
            let itemView = UIView()
            let tap = UITapGestureRecognizer(target: self, action: item.action)
            itemView.addGestureRecognizer(tap)
            itemView.isUserInteractionEnabled = true
            
            let iconView = UIImageView(image: UIImage(systemName: item.icon))
            iconView.tintColor = .black
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            
            let label = UILabel()
            label.text = item.title
            label.font = .systemFont(ofSize: 17)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            itemView.addSubview(iconView)
            itemView.addSubview(label)
            
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 16),
                iconView.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 22),
                iconView.heightAnchor.constraint(equalToConstant: 22),
                
                label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
                
                itemView.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            if item.showArrow {
                let arrowIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
                arrowIcon.tintColor = UIColor(white: 0.8, alpha: 1.0)
                arrowIcon.contentMode = .scaleAspectFit
                arrowIcon.translatesAutoresizingMaskIntoConstraints = false
                itemView.addSubview(arrowIcon)
                NSLayoutConstraint.activate([
                    arrowIcon.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -16),
                    arrowIcon.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
                    arrowIcon.widthAnchor.constraint(equalToConstant: 14),
                    arrowIcon.heightAnchor.constraint(equalToConstant: 14)
                ])
            }
            
            if item.showStars {
                let starsStack = UIStackView()
                starsStack.axis = .horizontal
                starsStack.spacing = 2
                starsStack.translatesAutoresizingMaskIntoConstraints = false
                for _ in 0..<5 {
                    let star = UIImageView(image: UIImage(systemName: "star.fill"))
                    star.tintColor = UIColor(red: 0.95, green: 0.65, blue: 0.31, alpha: 1.0) // 截图同款橙色
                    star.contentMode = .scaleAspectFit
                    NSLayoutConstraint.activate([
                        star.widthAnchor.constraint(equalToConstant: 16),
                        star.heightAnchor.constraint(equalToConstant: 16)
                    ])
                    starsStack.addArrangedSubview(star)
                }
                itemView.addSubview(starsStack)
                NSLayoutConstraint.activate([
                    starsStack.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -16),
                    starsStack.centerYAnchor.constraint(equalTo: itemView.centerYAnchor)
                ])
            }
            
            stack.addArrangedSubview(itemView)
            
            if index < items.count - 1 {
                let line = UIView()
                line.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
                line.translatesAutoresizingMaskIntoConstraints = false
                itemView.addSubview(line)
                NSLayoutConstraint.activate([
                    line.leadingAnchor.constraint(equalTo: label.leadingAnchor),
                    line.trailingAnchor.constraint(equalTo: itemView.trailingAnchor),
                    line.bottomAnchor.constraint(equalTo: itemView.bottomAnchor),
                    line.heightAnchor.constraint(equalToConstant: 0.5)
                ])
            }
        }
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        return card
    }
    
    // MARK: - Actions
    
    @objc private func contactUsTapped() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["support.beverg@gmail.com"])
            mail.setSubject(NSLocalizedString("feedback_subject", comment: "Feedback subject"))
            mail.setMessageBody("\n\n---\nDevice: \(UIDevice.current.model)\nSystem: \(UIDevice.current.systemVersion)", isHTML: false)
            present(mail, animated: true)
        } else {
            let email = "support.beverg@gmail.com"
            if let url = URL(string: "mailto:\(email)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    @objc private func rateAppTapped() {
        if let scene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    @objc private func recommendFriendsTapped() {
        let appLink = "https://apps.apple.com/app/id123456789" // 替换为实际的 App ID
        let text = NSLocalizedString("recommendation_message", comment: "Recommendation message")
        let activityVC = UIActivityViewController(activityItems: [text, appLink], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
}

// MARK: - MFMailComposeViewControllerDelegate
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
