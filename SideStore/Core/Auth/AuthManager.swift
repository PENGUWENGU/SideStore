//
//  AuthManager.swift
//  SideStore
//
//  Created by Magesh K on 1/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign
import CoreData

public final class AuthManager: @unchecked Sendable {
    public static let shared = AuthManager()
    public static let didChangeActiveAccountNotification = Notification.Name("com.sidestore.AuthManager.didChangeActiveAccount")
    
    private var portalProxy: DeveloperPortalProxyWithAuth {
        DeveloperPortalProxy.shared as! DeveloperPortalProxyWithAuth
    }
    
    private init() {}
    
    private var team: ALTTeam?
    private var session: ALTAppleAPISession?

    public var isAuthenticated: Bool {
        let hasEmail = Keychain.shared.appleIDEmailAddress != nil
        let hasPassword = Keychain.shared.appleIDPassword != nil
        let hasToken = Keychain.shared.appleIDXcodeToken != nil
        return hasEmail && (hasPassword || hasToken)
    }

    public var storedAccounts: [StoredAccountCredentials] {
        if self.isAuthenticated {
            Keychain.shared.syncActiveAccountToStore(
                teamIdentifier: self.team?.identifier,
                teamName: self.team?.name,
                teamTypeRawValue: self.team?.type.rawValue,
                certificateSerialNumber: CertificateManager.shared.activeCertificate?.serialNumber,
                isDeviceRegistered: UserDefaults.standard.isDeviceRegistered
            )
        }
        return Keychain.shared.getAllStoredAccounts()
    }
    
    public var currentAppleID: String? {
        get { Keychain.shared.appleIDEmailAddress }
        set {
            Keychain.shared.appleIDEmailAddress = newValue
            Keychain.shared.syncActiveAccountToStore()
        }
    }
    
    public var password: String? {
        get { Keychain.shared.appleIDPassword }
        set {
            Keychain.shared.appleIDPassword = newValue
            Keychain.shared.syncActiveAccountToStore()
        }
    }
    
    public var adsid: String? {
        get { Keychain.shared.appleIDAdsid }
        set {
            Keychain.shared.appleIDAdsid = newValue
            Keychain.shared.syncActiveAccountToStore()
        }
    }
    
    public var xcodeToken: String? {
        get { Keychain.shared.appleIDXcodeToken }
        set {
            Keychain.shared.appleIDXcodeToken = newValue
            Keychain.shared.syncActiveAccountToStore()
        }
    }
    
    public var hasStoredPassword: Bool {
        return Keychain.shared.appleIDPassword != nil
    }
    
    public var hasStoredXcodeToken: Bool {
        return Keychain.shared.appleIDXcodeToken != nil
    }
    
    public func signOut(
        keepCertificate: Bool = false,
        keepAnisetteData: Bool = true,
        keepAnisetteHeaders: Bool = true,
        keepSideSignHeaders: Bool = true
    ) async {
        let signingOutEmail = self.currentAppleID
        self.session = nil
        self.team = nil

        if let signingOutEmail {
            Keychain.shared.removeStoredAccount(forAppleID: signingOutEmail)
        }

        let remainingAccounts = Keychain.shared.getAllStoredAccounts()

        if !keepCertificate {
            debugLog("[AuthManager] Clearing signing certificate in cert manager and keychain.")
            CertificateManager.shared.clearActiveCertificate()
            debugLog("[AuthManager] Cleared signing certificate in cert manager and keychain.")
        } else {
            debugLog("[AuthManager] Preserved signing certificate in cert manager and keychain.")
        }

        if let nextAccount = remainingAccounts.first {
            debugLog("[AuthManager] Signed out of \(signingOutEmail ?? "current account"). Switching to next stored account: \(nextAccount.appleID)")
            try? await self.switchAccount(to: nextAccount.appleID)
            return
        }

        debugLog("[AuthManager] Clearing account and team info in database.")
        await DatabaseManager.shared.deactivateActiveAccountAndTeam()
        debugLog("[AuthManager] Cleared account and team info in database.")

        debugLog("[AuthManager] Clearing sign-in info from keychain.")
        Keychain.shared.clearSignInInfo(keepAnisetteData: keepAnisetteData)
        debugLog("[AuthManager] Cleared sign-in info from keychain.")

        if !keepAnisetteHeaders {
            debugLog("[AuthManager] Resetting Anisette header customizations to defaults.")
            AnisetteConfigManager.shared.resetToDefaults()
        }

        if !keepSideSignHeaders {
            debugLog("[AuthManager] Resetting SideSign header customizations to defaults.")
            SideSignConfigManager.shared.resetToDefaults()
        }

        AnisetteDataManager.shared.clearCache()

        await MainActor.run {
            NotificationCenter.default.post(name: Self.didChangeActiveAccountNotification, object: nil)
        }
    }

    public func switchAccount(to appleID: String) async throws {
        if self.isAuthenticated {
            Keychain.shared.syncActiveAccountToStore(
                teamIdentifier: self.team?.identifier,
                teamName: self.team?.name,
                teamTypeRawValue: self.team?.type.rawValue,
                certificateSerialNumber: CertificateManager.shared.activeCertificate?.serialNumber,
                isDeviceRegistered: UserDefaults.standard.isDeviceRegistered
            )
        }

        guard let targetRecord = Keychain.shared.getStoredAccount(forAppleID: appleID) else {
            throw OperationError.notAuthenticated
        }

        debugLog("[AuthManager] Switching active account to \(targetRecord.appleID) (team: \(targetRecord.teamIdentifier ?? "nil"))")

        self.session = nil
        self.team = nil

        Keychain.shared.appleIDEmailAddress = targetRecord.appleID
        Keychain.shared.appleIDPassword = targetRecord.password
        Keychain.shared.appleIDAdsid = targetRecord.adsid
        Keychain.shared.appleIDXcodeToken = targetRecord.xcodeToken

        if let isReg = targetRecord.isDeviceRegistered {
            UserDefaults.standard.isDeviceRegistered = isReg
        }

        CertificateManager.shared.restoreCertificateForAccount(targetRecord)

        await DatabaseManager.shared.activateStoredAccount(targetRecord)
        self.team = try? await self.resolveActiveTeam()

        await MainActor.run {
            NotificationCenter.default.post(name: Self.didChangeActiveAccountNotification, object: nil)
        }
    }

    @discardableResult
    func addAccount(presentingViewController: UIViewController? = nil) async throws -> SignInResult {
        let previousAppleID = self.isAuthenticated ? self.currentAppleID : nil
        if self.isAuthenticated {
            Keychain.shared.syncActiveAccountToStore(
                teamIdentifier: self.team?.identifier,
                teamName: self.team?.name,
                teamTypeRawValue: self.team?.type.rawValue,
                certificateSerialNumber: CertificateManager.shared.activeCertificate?.serialNumber,
                isDeviceRegistered: UserDefaults.standard.isDeviceRegistered
            )
        }

        // Prepare clean active slot for the new account sign-in
        self.session = nil
        self.team = nil
        Keychain.shared.clearSignInInfo(keepAnisetteData: true)
        CertificateManager.shared.clearActiveCertificate()
        UserDefaults.standard.isDeviceRegistered = false

        do {
            let hasExistingAccount = (previousAppleID != nil)
            let result = try await self.signIn(
                presentingViewController: presentingViewController,
                skipResign: hasExistingAccount,
                skipHowTos: hasExistingAccount
            )
            Keychain.shared.syncActiveAccountToStore(
                teamIdentifier: result.team.identifier,
                teamName: result.team.name,
                teamTypeRawValue: result.team.type.rawValue,
                accountIdentifier: result.team.account?.identifier,
                firstName: result.team.account?.firstName,
                lastName: result.team.account?.lastName,
                certificateSerialNumber: result.certificate?.serialNumber ?? CertificateManager.shared.activeCertificate?.serialNumber,
                isDeviceRegistered: UserDefaults.standard.isDeviceRegistered
            )
            await MainActor.run {
                NotificationCenter.default.post(name: Self.didChangeActiveAccountNotification, object: nil)
            }
            return result
        } catch {
            debugLog("[AuthManager] addAccount failed or cancelled: \(error). Restoring previous account if available...")
            if let previousAppleID {
                try? await self.switchAccount(to: previousAppleID)
            }
            throw error
        }
    }

    public func removeAccount(appleID: String, keepCertificate: Bool = true) async {
        let normalizedTarget = Keychain.normalizeAppleID(appleID)
        let normalizedCurrent = self.currentAppleID.map { Keychain.normalizeAppleID($0) }

        if normalizedTarget == normalizedCurrent {
            await self.signOut(keepCertificate: keepCertificate)
            return
        }

        if !keepCertificate,
           let record = Keychain.shared.getStoredAccount(forAppleID: appleID),
           let serial = record.certificateSerialNumber,
           CertificateManager.shared.activeCertificate?.serialNumber != serial {
            CertificateManager.shared.deleteCertificate(serialNumber: serial)
        }

        Keychain.shared.removeStoredAccount(forAppleID: appleID)

        await MainActor.run {
            NotificationCenter.default.post(name: Self.didChangeActiveAccountNotification, object: nil)
        }
    }
    
    @discardableResult
    public func getAuthenticatedSession() async throws -> ALTAppleAPISession {
        return try await TaskChainCoalescer.shared.coalesce(key: "apple_auth_session") {
            guard let adsid = self.adsid,                           // directory services id
                  let xcodeToken = self.xcodeToken else             // xcode token
            {
                debugLog("[AuthManager] No stored tokens found.")
                throw OperationError.notAuthenticated
            }
            let anisetteData = try await AnisetteProvider.fetch()   // one time pass
            let xcodeVersion = await AnisetteConfigManager.shared.resolvedXcodeVersion()
            
            let session = ALTAppleAPISession(
                dsid: adsid,
                authToken: xcodeToken,
                anisetteData: anisetteData,
                xcodeVersion: xcodeVersion
            )
            self.session = session
            return session
        }
    }

    @discardableResult
    public func getAuthenticatedSession(forTeamIdentifier teamID: String?) async throws -> ALTAppleAPISession {
        guard let teamID, !teamID.isEmpty else {
            return try await self.getAuthenticatedSession()
        }
        if let activeTeam = try? await self.getAuthenticatedTeam(), activeTeam.identifier == teamID {
            return try await self.getAuthenticatedSession()
        }
        if let stored = Keychain.shared.getStoredAccount(forTeamIdentifier: teamID),
           let adsid = stored.adsid, !adsid.isEmpty,
           let xcodeToken = stored.xcodeToken, !xcodeToken.isEmpty {
            return try await TaskChainCoalescer.shared.coalesce(key: "apple_auth_session_\(teamID)") {
                let anisetteData = try await AnisetteProvider.fetch()
                let xcodeVersion = await AnisetteConfigManager.shared.resolvedXcodeVersion()
                return ALTAppleAPISession(
                    dsid: adsid,
                    authToken: xcodeToken,
                    anisetteData: anisetteData,
                    xcodeVersion: xcodeVersion
                )
            }
        }
        return try await self.getAuthenticatedSession()
    }

    public func getAuthenticatedTeam() async throws -> ALTTeam {
        if let team = self.team {
            return team
        }
        
        let team = try await self.resolveActiveTeam()
        self.team = team
        Keychain.shared.syncActiveAccountToStore(
            teamIdentifier: team.identifier,
            teamName: team.name,
            teamTypeRawValue: team.type.rawValue
        )
        return team
    }

    public func getAuthenticatedTeam(preferringInstalledApp installedApp: InstalledApp?, isRefreshOnly: Bool = false) async throws -> ALTTeam {
        if isRefreshOnly, let installedApp {
            let appTeamInfo: (identifier: String, name: String, type: ALTTeamType)? = await DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
                guard let appInContext = try? context.existingObject(with: installedApp.objectID) as? InstalledApp,
                      let dbTeam = appInContext.team else {
                    return nil
                }
                return (dbTeam.identifier, dbTeam.name, dbTeam.type)
            }
            if let appTeamInfo,
               let stored = Keychain.shared.getStoredAccount(forTeamIdentifier: appTeamInfo.identifier),
               stored.adsid != nil && stored.xcodeToken != nil {
                return ALTTeam(identifier: appTeamInfo.identifier, name: appTeamInfo.name, type: appTeamInfo.type)
            }
        }
        return try await self.getAuthenticatedTeam()
    }

    private func resolveActiveTeam() async throws -> ALTTeam {
        try await DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
            if let dbTeam = DatabaseManager.shared.activeTeam(in: context) {
                return ALTTeam(identifier: dbTeam.identifier, name: dbTeam.name, type: dbTeam.type)
            }
            if let currentEmail = Keychain.shared.appleIDEmailAddress,
               let stored = Keychain.shared.getStoredAccount(forAppleID: currentEmail),
               let teamID = stored.teamIdentifier {
                let teamType = ALTTeamType(rawValue: stored.teamTypeRawValue ?? 0) ?? .free
                return ALTTeam(identifier: teamID, name: stored.teamName ?? stored.displayName, type: teamType)
            }
            throw OperationError.notAuthenticated
        }
    }
    
    @discardableResult
    func signIn(
        presentingViewController: UIViewController? = nil,
        skipDeviceRegistration: Bool = false,
        skipCertificateProvisioning: Bool = false,
        skipResign: Bool = false,
        skipHowTos: Bool = false
    ) async throws -> SignInResult {
        let dbBackgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let signInFlowHandler = SignInFlowHandler(presentingViewController: presentingViewController)
        let context = StandaloneOperationContext(
            steps: .signIn,
            dbBackgroundContext: dbBackgroundContext
        )
        
        let signInOperation = try SignInOperation(
            context: context,
            signInHandler: signInFlowHandler,
            anisetteServerHandler: signInFlowHandler,
            skipDeviceRegistration: skipDeviceRegistration,
            skipCertificateProvisioning: skipCertificateProvisioning,
            skipResign: skipResign,
            skipHowTos: skipHowTos
        )
        let result = try await signInOperation.execute()
        self.team = result.team
        self.session = result.session
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didChangeActiveAccountNotification, object: nil)
        }
        return result
    }
    
    
    // Developer Portal Operations
    public func signIn(appleID: String, 
                       password: String, 
                       anisetteData: ALTAnisetteData, 
                       xcodeVersion: String, 
                       machinePassword: String? = nil,
                       accountRepairHandler: DeveloperPortal.AccountRepairHandler = DeveloperPortal.defaultAccountRepairHandler,
                       verificationHandler: DeveloperPortal.VerificationHandler?) async throws -> (ALTAccount, ALTAppleAPISession) 
    {
        return try await self.portalProxy.signIn(
            appleID: appleID, 
            password: password, 
            anisetteData: anisetteData, 
            xcodeVersion: xcodeVersion, 
            machinePassword: machinePassword,
            accountRepairHandler: accountRepairHandler, 
            verificationHandler: verificationHandler
        )
    }
}

fileprivate extension DatabaseManager {
    //TODO: this is not clean, but for now this should be fine, ie we should later make this proper async instead of blocking
    func deactivateActiveAccountAndTeam() async {
        guard self.isStarted else {
            debugLog("[AuthManager] DatabaseManager is not started. Skipping CoreData active account/team deactivation.")
            return
        }
        let bgContext = self.persistentContainer.newBackgroundContext()
        await bgContext.perform {
            if let account = self.activeAccount(in: bgContext) {
                account.isActiveAccount = false
            }
            if let team = self.activeTeam(in: bgContext) {
                team.isActiveTeam = false
            }
            do {
                try bgContext.save()
            } catch {
                debugLog("[AuthManager] Failed to save CoreData context when deactivating active account and team: \(error)")
            }
        }
        
        await self.viewContext.perform {
            self.viewContext.processPendingChanges()
            self.viewContext.refreshAllObjects()
        }
    }

    func activateStoredAccount(_ record: StoredAccountCredentials) async {
        guard self.isStarted else { return }
        let bgContext = self.persistentContainer.newBackgroundContext()
        await bgContext.perform {
            let allAccounts = (try? bgContext.fetch(Account.fetchRequest())) ?? []
            for acc in allAccounts {
                acc.isActiveAccount = false
            }

            let allTeams = (try? bgContext.fetch(Team.fetchRequest())) ?? []
            for tm in allTeams {
                tm.isActiveTeam = false
            }

            let targetAccount: Account
            if let accountID = record.accountIdentifier,
               let found = allAccounts.first(where: { $0.identifier == accountID }) {
                targetAccount = found
            } else if let foundByEmail = allAccounts.first(where: { $0.appleID.caseInsensitiveCompare(record.appleID) == .orderedSame }) {
                targetAccount = foundByEmail
            } else {
                let altAcc = ALTAccount(appleID: record.appleID, identifier: record.accountIdentifier ?? record.teamIdentifier ?? record.normalizedAppleID)
                targetAccount = Account(altAcc, context: bgContext)
                if let first = record.firstName { targetAccount.firstName = first }
                if let last = record.lastName { targetAccount.lastName = last }
            }
            targetAccount.isActiveAccount = true

            if let teamID = record.teamIdentifier {
                let targetTeam: Team
                if let foundTeam = allTeams.first(where: { $0.identifier == teamID }) {
                    targetTeam = foundTeam
                } else {
                    let teamType = ALTTeamType(rawValue: record.teamTypeRawValue ?? 0) ?? .free
                    let altTeam = ALTTeam(identifier: teamID, name: record.teamName ?? targetAccount.localizedName, type: teamType)
                    targetTeam = Team(altTeam, account: targetAccount, context: bgContext)
                }
                targetTeam.isActiveTeam = true

                let isSparseRestorePatched = ProcessInfo().sparseRestorePatched
                let isAppLimitDisabled = UserDefaults.standard.isAppLimitDisabled
                UserDefaults.standard.activeAppsLimit = nil
                if targetTeam.type == .free {
                    if (!isAppLimitDisabled && isSparseRestorePatched) || (isAppLimitDisabled && !isSparseRestorePatched) {
                        UserDefaults.standard.activeAppsLimit = InstalledApp.freeAccountActiveAppsLimit
                    }
                }
            } else if let firstTeam = targetAccount.teams.first {
                firstTeam.isActiveTeam = true
            }

            do {
                if bgContext.hasChanges {
                    try bgContext.save()
                }
            } catch {
                debugLog("[AuthManager] Failed to save CoreData context when activating stored account: \(error)")
            }
        }

        await self.viewContext.perform {
            self.viewContext.processPendingChanges()
            self.viewContext.refreshAllObjects()
        }
    }
}
