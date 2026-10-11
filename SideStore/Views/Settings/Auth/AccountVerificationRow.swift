//
//  AccountVerificationRow.swift
//  SideStore
//
//  Created by Magesh K on 13/09/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign

final class AccountVerificationRow: InsetGroupTableViewCell {
    static let reuseIdentifier = "AccountVerificationRow"
    static let preferredHeight: CGFloat = 60.0
    
    enum Status: Equatable {
        case completed
        case checking
        case actionRequired(certMissing: Bool, deviceUnregistered: Bool)
    }
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    
    init(reuseIdentifier: String? = AccountVerificationRow.reuseIdentifier) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupViews()
    }
    
    private func setupViews() {
        self.style = .bottom
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
        self.tintColor = UIColor.white.withAlphaComponent(0.6)
        self.layoutMargins = UIEdgeInsets(top: 8, left: 30, bottom: 8, right: 30)
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        self.subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        self.subtitleLabel.numberOfLines = 2
        
        self.iconImageView.translatesAutoresizingMaskIntoConstraints = false
        self.iconImageView.contentMode = .scaleAspectFit
        
        self.spinner.translatesAutoresizingMaskIntoConstraints = false
        self.spinner.color = .white
        self.spinner.hidesWhenStopped = true
        
        let textStack = UIStackView(arrangedSubviews: [self.titleLabel, self.subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let rightContainer = UIView()
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(self.iconImageView)
        rightContainer.addSubview(self.spinner)
        
        let mainStack = UIStackView(arrangedSubviews: [textStack, rightContainer])
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.distribution = .fill
        
        self.contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 30),
            mainStack.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -30),
            mainStack.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8),
            mainStack.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -8),
            
            rightContainer.widthAnchor.constraint(equalToConstant: 24),
            rightContainer.heightAnchor.constraint(equalToConstant: 24),
            
            self.iconImageView.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            self.iconImageView.centerYAnchor.constraint(equalTo: rightContainer.centerYAnchor),
            self.iconImageView.widthAnchor.constraint(equalToConstant: 22),
            self.iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            self.spinner.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            self.spinner.centerYAnchor.constraint(equalTo: rightContainer.centerYAnchor)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.style = .bottom
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
    }
    
    func configure(with status: Status) {
        self.style = .bottom
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
        switch status {
        case .completed:
            self.titleLabel.text = nil
            self.subtitleLabel.text = nil
            self.iconImageView.image = nil
            self.iconImageView.isHidden = true
            self.spinner.stopAnimating()
            self.accessoryType = .none
            self.isSelectable = false
            
        case .checking:
            self.titleLabel.text = NSLocalizedString("Account Verification", comment: "")
            self.titleLabel.textColor = .white
            self.subtitleLabel.text = NSLocalizedString("Verifying account status...", comment: "")
            self.subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            self.iconImageView.image = nil
            self.iconImageView.isHidden = true
            self.spinner.startAnimating()
            self.accessoryType = .none
            self.isSelectable = false
            
        case .actionRequired(let certMissing, let deviceUnregistered):
            self.titleLabel.text = NSLocalizedString("Action Required", comment: "")
            self.titleLabel.textColor = .systemOrange
            
            let subtitle: String
            if certMissing && deviceUnregistered {
                subtitle = NSLocalizedString("Signing certificate & device registration pending", comment: "")
            } else if certMissing {
                subtitle = NSLocalizedString("Active signing certificate pending", comment: "")
            } else {
                subtitle = NSLocalizedString("Device registration pending", comment: "")
            }
            self.subtitleLabel.text = subtitle
            self.subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
            
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
            self.iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: symbolConfig)?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
            self.iconImageView.isHidden = false
            self.spinner.stopAnimating()
            self.accessoryType = .none
            self.isSelectable = true
        }
    }
}

extension AccountVerificationRow {
    static func verifyStatus(for team: ALTTeam) async -> Status {
        let hasActiveCert = CertificateManager.shared.activeCertificate != nil || (try? CertificateManager.shared.loadActiveCertificate()) != nil
        let certMissing = !hasActiveCert
        let isDeviceRegistered = UserDefaults.standard.isDeviceRegistered
        
        if isDeviceRegistered {
            if certMissing {
                return .actionRequired(certMissing: true, deviceUnregistered: false)
            } else {
                return .completed
            }
        }
        
        do {
            let devices = try await DeveloperPortalProxy.shared.fetchDevices(for: team, types: .all)
            let udid = try await fetchUDID()
            let isMatch = devices.contains { $0.identifier.caseInsensitiveCompare(udid) == .orderedSame }
            
            if isMatch {
                UserDefaults.standard.isDeviceRegistered = true
                Keychain.shared.syncActiveAccountToStore(
                    teamIdentifier: team.identifier,
                    teamName: team.name,
                    teamTypeRawValue: team.type.rawValue,
                    certificateSerialNumber: CertificateManager.shared.activeCertificate?.serialNumber,
                    isDeviceRegistered: true
                )
                if certMissing {
                    return .actionRequired(certMissing: true, deviceUnregistered: false)
                } else {
                    return .completed
                }
            } else {
                return .actionRequired(certMissing: certMissing, deviceUnregistered: true)
            }
        } catch {
            verboseLog("[AccountVerificationRow] verifyStatus error fetching devices: \(error)")
            return .actionRequired(certMissing: certMissing, deviceUnregistered: true)
        }
    }
    
    static func resolvePendingActions(for status: Status, team: ALTTeam, presentingViewController: UIViewController) async {
        guard case .actionRequired(let certMissing, let deviceUnregistered) = status else { return }
        
        var pendingItems: [String] = []
        if deviceUnregistered {
            pendingItems.append(NSLocalizedString("Register Device", comment: ""))
        }
        if certMissing {
            pendingItems.append(NSLocalizedString("Provision Signing Certificate", comment: ""))
        }
        
        guard !pendingItems.isEmpty else { return }
        
        let count = pendingItems.count
        let title = count == 1
            ? NSLocalizedString("1 Pending Action", comment: "")
            : String(format: NSLocalizedString("%d Pending Actions", comment: ""), count)
        
        let bulletList = pendingItems.map { "• \($0)" }.joined(separator: "\n")
        let message = NSLocalizedString("The following action(s) from sign-in are required to complete account setup:\n\n\(bulletList)", comment: "")
        
        let confirmed = await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            })
            presentingViewController.present(alert, animated: true)
        }
        
        guard confirmed else { return }
        
        let initialDescription = deviceUnregistered
            ? NSLocalizedString("Registering device…", comment: "")
            : NSLocalizedString("Provisioning signing certificate…", comment: "")
            
        let progressAlert = UIAlertController(
            title: NSLocalizedString("Setting Up Account", comment: ""),
            message: "\(initialDescription)\n\n\n",
            preferredStyle: .alert
        )
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        progressAlert.view.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: progressAlert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: progressAlert.view.bottomAnchor, constant: -20)
        ])
        
        await withCheckedContinuation { continuation in
            presentingViewController.present(progressAlert, animated: true) {
                continuation.resume()
            }
        }
        
        func executeStep(description: String, operation: () async throws -> Void) async throws {
            progressAlert.message = "\(description)\n\n\n"
            let startTime = Date()
            try await operation()
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 0.5 {
                try? await Task.sleep(nanoseconds: UInt64((0.5 - elapsed) * 1_000_000_000))
            }
        }
        
        let handler = SignInFlowHandler(presentingViewController: presentingViewController)
        handler.showsDoItLater = true
        
        do {
            if deviceUnregistered {
                try await executeStep(description: NSLocalizedString("Registering device…", comment: "")) {
                    let deviceFlow = DeviceRegistrationFlow(handler: handler)
                    _ = try await deviceFlow.registerCurrentDevice(for: team)
                }
            }
            
            if certMissing {
                try await executeStep(description: NSLocalizedString("Provisioning signing certificate…", comment: "")) {
                    let certFlow = CertificateProvisioningFlow(handler: handler)
                    _ = try await certFlow.resolveCertificate(for: team)
                }
            }
        } catch {
            verboseLog("[AccountVerificationRow] resolvePendingActions error: \(error)")
        }
        
        await withCheckedContinuation { continuation in
            progressAlert.dismiss(animated: true) {
                continuation.resume()
            }
        }

        Keychain.shared.syncActiveAccountToStore(
            teamIdentifier: team.identifier,
            teamName: team.name,
            teamTypeRawValue: team.type.rawValue,
            certificateSerialNumber: CertificateManager.shared.activeCertificate?.serialNumber,
            isDeviceRegistered: UserDefaults.standard.isDeviceRegistered
        )
        
        if UserDefaults.standard.isDeviceRegistered,
           let activeCert = CertificateManager.shared.activeCertificate?.certificate ?? (try? CertificateManager.shared.loadActiveCertificate())?.certificate
        {
            let resignFlow = CodeSignValidationFlow(handler: handler)
            _ = try? await resignFlow.validateAndResignIfNeeded(
                team: team,
                certificate: activeCert
            )
        }
        
        await handler.complete()
    }
}

final class AccountSwitcherRow: InsetGroupTableViewCell {
    static let reuseIdentifier = "AccountSwitcherRow"
    static let preferredHeight: CGFloat = 60.0

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()

    init(reuseIdentifier: String? = AccountSwitcherRow.reuseIdentifier) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupViews()
    }

    private func setupViews() {
        self.style = .bottom
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
        self.tintColor = UIColor.white.withAlphaComponent(0.6)
        self.layoutMargins = UIEdgeInsets(top: 8, left: 30, bottom: 8, right: 30)

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        self.titleLabel.textColor = .white

        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        self.subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        self.subtitleLabel.numberOfLines = 2

        self.iconImageView.translatesAutoresizingMaskIntoConstraints = false
        self.iconImageView.contentMode = .scaleAspectFit

        let textStack = UIStackView(arrangedSubviews: [self.titleLabel, self.subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let rightContainer = UIView()
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(self.iconImageView)

        let mainStack = UIStackView(arrangedSubviews: [textStack, rightContainer])
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.distribution = .fill

        self.contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 30),
            mainStack.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -30),
            mainStack.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8),
            mainStack.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -8),

            rightContainer.widthAnchor.constraint(equalToConstant: 24),
            rightContainer.heightAnchor.constraint(equalToConstant: 24),

            self.iconImageView.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            self.iconImageView.centerYAnchor.constraint(equalTo: rightContainer.centerYAnchor),
            self.iconImageView.widthAnchor.constraint(equalToConstant: 22),
            self.iconImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.style = .bottom
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
    }

    func configure(accountCount: Int, isBottomCell: Bool) {
        self.style = isBottomCell ? .bottom : .middle
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.backgroundConfiguration = .clear()
        self.isSelectable = true

        if accountCount > 1 {
            self.titleLabel.text = NSLocalizedString("Switch or Add Account", comment: "")
            self.subtitleLabel.text = String(format: NSLocalizedString("%d Apple IDs signed in • Tap to manage", comment: ""), accountCount)
        } else {
            self.titleLabel.text = NSLocalizedString("Add or Switch Account", comment: "")
            self.subtitleLabel.text = NSLocalizedString("Sign in with another Apple ID or switch accounts", comment: "")
        }

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        self.iconImageView.image = UIImage(systemName: "person.2.fill", withConfiguration: symbolConfig)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        self.iconImageView.isHidden = false
    }
}

final class AccountsManagementViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case accounts
        case actions
    }

    private var accounts: [StoredAccountCredentials] = []
    private var isSwitching = false
    private weak var hostViewController: UIViewController?
    private let onAccountChanged: (() -> Void)?

    init(hostViewController: UIViewController?, onAccountChanged: (() -> Void)? = nil) {
        self.hostViewController = hostViewController
        self.onAccountChanged = onAccountChanged
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("Accounts", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSelf)
        )
        self.reloadAccounts()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChangedNotification),
            name: AuthManager.didChangeActiveAccountNotification,
            object: nil
        )
    }

    @objc private func dismissSelf() {
        self.dismiss(animated: true)
    }

    @objc private func handleAccountChangedNotification() {
        self.reloadAccounts()
    }

    private func reloadAccounts() {
        self.accounts = AuthManager.shared.storedAccounts
        self.tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .accounts:
            return max(self.accounts.count, 1)
        case .actions:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .accounts:
            return NSLocalizedString("Signed-In Apple IDs", comment: "")
        case .actions:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .accounts:
            return NSLocalizedString("Tap an account to make it active for installing or resigning apps. Installed apps automatically refresh using the account they were signed with.", comment: "")
        case .actions:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sec {
        case .accounts:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AccountCell")
            guard !self.accounts.isEmpty else {
                cell.textLabel?.text = NSLocalizedString("No Signed-In Accounts", comment: "")
                cell.textLabel?.textColor = .secondaryLabel
                cell.selectionStyle = .none
                return cell
            }

            let account = self.accounts[indexPath.row]
            let currentEmail = AuthManager.shared.currentAppleID.map { Keychain.normalizeAppleID($0) }
            let isActive = (account.normalizedAppleID == currentEmail)

            cell.textLabel?.text = account.displayName
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: isActive ? .semibold : .regular)

            var detailParts: [String] = [account.appleID]
            if let teamID = account.teamIdentifier, !teamID.isEmpty {
                let teamType = ALTTeamType(rawValue: account.teamTypeRawValue ?? 0) ?? .free
                detailParts.append("\(teamType.localizedDescription) (\(teamID))")
            }
            cell.detailTextLabel?.text = detailParts.joined(separator: " • ")
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.numberOfLines = 2
            cell.accessoryType = isActive ? .checkmark : .none
            cell.tintColor = .altPrimary
            return cell

        case .actions:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "ActionCell")
            cell.textLabel?.text = NSLocalizedString("Add Apple ID…", comment: "")
            cell.textLabel?.textColor = .altPrimary
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            cell.imageView?.image = UIImage(systemName: "plus.circle.fill")
            cell.imageView?.tintColor = .altPrimary
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.isSwitching, let sec = Section(rawValue: indexPath.section) else { return }

        switch sec {
        case .accounts:
            guard indexPath.row < self.accounts.count else { return }
            let selected = self.accounts[indexPath.row]
            let currentEmail = AuthManager.shared.currentAppleID.map { Keychain.normalizeAppleID($0) }
            guard selected.normalizedAppleID != currentEmail else { return }

            self.isSwitching = true
            Task { @MainActor in
                defer { self.isSwitching = false }
                do {
                    try await AuthManager.shared.switchAccount(to: selected.appleID)
                    self.reloadAccounts()
                    self.onAccountChanged?()
                } catch {
                    let alert = UIAlertController(
                        title: NSLocalizedString("Failed to Switch Account", comment: ""),
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: UIAlertAction.ok.title, style: .default))
                    self.present(alert, animated: true)
                }
            }

        case .actions:
            let presenter = self.hostViewController ?? self.presentingViewController ?? self
            self.dismiss(animated: true) {
                Task { @MainActor in
                    do {
                        _ = try await AuthManager.shared.addAccount(presentingViewController: presenter)
                        self.onAccountChanged?()
                    } catch OperationError.cancelled {
                        // User cancelled sign-in
                    } catch {
                        let toastView = ToastView(error: error)
                        toastView.show(in: presenter)
                    }
                }
            }
        }
    }

    #if !os(tvOS)
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard Section(rawValue: indexPath.section) == .accounts else { return false }
        return !self.accounts.isEmpty
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .accounts,
              indexPath.row < self.accounts.count else { return nil }

        let account = self.accounts[indexPath.row]
        let removeAction = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("Remove", comment: "")
        ) { [weak self] _, _, completionHandler in
            guard let self else {
                completionHandler(false)
                return
            }
            self.confirmRemoveAccount(account, completionHandler: completionHandler)
        }
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    #endif

    private func confirmRemoveAccount(_ account: StoredAccountCredentials, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: String(format: NSLocalizedString("Remove “%@”?", comment: ""), account.appleID),
            message: NSLocalizedString("Do you want to keep the signing certificate for this Apple ID in the Keychain?", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove & Keep Certificate", comment: ""), style: .default) { [weak self] _ in
            Task { @MainActor in
                await AuthManager.shared.removeAccount(appleID: account.appleID, keepCertificate: true)
                self?.reloadAccounts()
                self?.onAccountChanged?()
                completionHandler(true)
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove & Delete Certificate", comment: ""), style: .destructive) { [weak self] _ in
            Task { @MainActor in
                await AuthManager.shared.removeAccount(appleID: account.appleID, keepCertificate: false)
                self?.reloadAccounts()
                self?.onAccountChanged?()
                completionHandler(true)
            }
        })
        self.present(alert, animated: true)
    }
}

