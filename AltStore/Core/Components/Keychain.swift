//
//  Keychain.swift
//  AltStore
//
//  Created by Riley Testut on 6/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
private import KeychainAccess
import SideSign

@propertyWrapper
public struct KeychainItem<Value>
{
    public let key: String
    
    public var wrappedValue: Value? {
        get {
            switch Value.self
            {
            case is Data.Type: return try? Keychain.shared.keychain.getData(self.key) as? Value
            case is String.Type: return try? Keychain.shared.keychain.getString(self.key) as? Value
            default: return nil
            }
        }
        set {
            switch Value.self
            {
            case is Data.Type: Keychain.shared.keychain[data: self.key] = newValue as? Data
            case is String.Type: Keychain.shared.keychain[self.key] = newValue as? String
            default: break
            }
        }
    }
    
    public init(key: String)
    {
        self.key = key
    }
}

public class Keychain
{
    public static let shared = Keychain()
    
    fileprivate let keychain = KeychainAccess.Keychain(service: Bundle.Info.appbundleIdentifier)
                                            .accessibility(.afterFirstUnlock)
                                            .synchronizable(true)
    
    @KeychainItem(key: "appleIDEmailAddress")
    public var appleIDEmailAddress: String?
    
    @KeychainItem(key: "appleIDPassword")
    public var appleIDPassword: String?
    
    @KeychainItem(key: "appleIDAdsid")
    public var appleIDAdsid: String?
    
    @KeychainItem(key: "appleIDXcodeToken")
    public var appleIDXcodeToken: String?
    
    @KeychainItem(key: "signingCertificate")
    public var signingCertificate: Data?
    
    @KeychainItem(key: "signingCertificatePassword")
    public var signingCertificatePassword: String?
    
    // TODO: mahee96: remove legacy keys in later versions after 0.6.4 coz by now our migrations should be effectively moved all
    // Legacy
    @KeychainItem(key: "signingCertificatePrivateKey")
    public var signingCertificatePrivateKey: Data?
    
    // TODO: mahee96: remove legacy keys in later versions after 0.6.4 coz by now our migrations should be effectively moved all
    // Legacy
    @KeychainItem(key: "signingCertificateSerialNumber")
    public var signingCertificateSerialNumber: String?
    
    @KeychainItem(key: "identifier")
    public var identifier: String?
    
    @KeychainItem(key: "adiPb")
    public var adiPb: String?

    @KeychainItem(key: "deviceUDID")
    public var deviceUDID: String?

    // MARK: - Dynamic Imported Certificates Storage

    public subscript(certificateSerial serial: String) -> Data? {
        get { try? self.keychain.getData("importedCert_" + serial) }
        set {
            if let data = newValue {
                try? self.keychain.set(data, key: "importedCert_" + serial)
            } else {
                try? self.keychain.remove("importedCert_" + serial)
            }
        }
    }

    // MARK: - Multi-Account Credentials Storage

    private let storedAccountsKey = "storedAccounts_v1"

    public func getAllStoredAccounts() -> [StoredAccountCredentials] {
        guard let data = try? self.keychain.getData(self.storedAccountsKey),
              let accounts = try? JSONDecoder().decode([StoredAccountCredentials].self, from: data) else {
            return []
        }
        return accounts
    }

    private func setAllStoredAccounts(_ accounts: [StoredAccountCredentials]) {
        if let data = try? JSONEncoder().encode(accounts) {
            try? self.keychain.set(data, key: self.storedAccountsKey)
        }
    }

    public static func normalizeAppleID(_ appleID: String) -> String {
        return appleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func getStoredAccount(forAppleID appleID: String) -> StoredAccountCredentials? {
        let normalized = Self.normalizeAppleID(appleID)
        return self.getAllStoredAccounts().first { $0.normalizedAppleID == normalized }
    }

    public func getStoredAccount(forTeamIdentifier teamID: String) -> StoredAccountCredentials? {
        guard !teamID.isEmpty else { return nil }
        return self.getAllStoredAccounts().first { $0.teamIdentifier == teamID }
    }

    public func saveStoredAccount(_ record: StoredAccountCredentials) {
        var accounts = self.getAllStoredAccounts()
        if let idx = accounts.firstIndex(where: { $0.normalizedAppleID == record.normalizedAppleID }) {
            accounts[idx] = record
        } else {
            accounts.append(record)
        }
        self.setAllStoredAccounts(accounts)
    }

    public func removeStoredAccount(forAppleID appleID: String) {
        let normalized = Self.normalizeAppleID(appleID)
        var accounts = self.getAllStoredAccounts()
        accounts.removeAll { $0.normalizedAppleID == normalized }
        self.setAllStoredAccounts(accounts)
    }

    @discardableResult
    public func syncActiveAccountToStore(
        teamIdentifier: String? = nil,
        teamName: String? = nil,
        teamTypeRawValue: Int? = nil,
        accountIdentifier: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        certificateSerialNumber: String? = nil,
        isDeviceRegistered: Bool? = nil
    ) -> StoredAccountCredentials? {
        guard let email = self.appleIDEmailAddress, !email.isEmpty else { return nil }
        let normalized = Self.normalizeAppleID(email)
        var existing = self.getStoredAccount(forAppleID: email) ?? StoredAccountCredentials(
            appleID: email,
            normalizedAppleID: normalized,
            updatedAt: Date()
        )

        existing.appleID = email
        existing.normalizedAppleID = normalized
        if let password = self.appleIDPassword { existing.password = password }
        if let adsid = self.appleIDAdsid { existing.adsid = adsid }
        if let xcodeToken = self.appleIDXcodeToken { existing.xcodeToken = xcodeToken }
        if let certData = self.signingCertificate {
            existing.certificateData = certData
            existing.certificatePassword = self.signingCertificatePassword
        }
        if let serial = certificateSerialNumber {
            existing.certificateSerialNumber = serial
        }
        if let teamIdentifier { existing.teamIdentifier = teamIdentifier }
        if let teamName { existing.teamName = teamName }
        if let teamTypeRawValue { existing.teamTypeRawValue = teamTypeRawValue }
        if let accountIdentifier { existing.accountIdentifier = accountIdentifier }
        if let firstName { existing.firstName = firstName }
        if let lastName { existing.lastName = lastName }
        if let isDeviceRegistered { existing.isDeviceRegistered = isDeviceRegistered }
        existing.updatedAt = Date()

        self.saveStoredAccount(existing)
        return existing
    }
    
    private init()
    {
        self.migrateLegacyKeychainItems()
        _ = self.syncActiveAccountToStore()
    }
    
    private func migrateLegacyKeychainItems()
    {
        let signingCertificateKey   = "signingCertificate"
        let privateKeyKey           = "signingCertificatePrivateKey"
        let serialNumberKey         = "signingCertificateSerialNumber"
        
        // 1. Check if signingCertificate contains data and is NOT a PKCS#12 archive
        guard let certData = try? self.keychain.getData(signingCertificateKey), !certData.isPKCS12 else { return }
        
        // 2. Check if we have the private key
        guard let privateKey = try? self.keychain.getData(privateKeyKey) else { return }
        
        // 3. Load the raw certificate and pair with private key
        guard let x509 = ALTX509Certificate(data: certData) else { return }
        let cert = ALTCertificate(x509: x509, privateKey: privateKey)
        
        // 4. Create PKCS12 data structure
        do {
            let p12Data = try cert.unencryptedP12Data()
            // 5. Store the new PKCS12 format in signingCertificate slot
            try self.keychain.set(p12Data, key: signingCertificateKey)
            try self.keychain.set("", key: "signingCertificatePassword")
            
            // 6. Clear legacy keys
            try self.keychain.remove(privateKeyKey)
            try self.keychain.remove(serialNumberKey)
            
            debugLog("[Keychain] Successfully migrated legacy certificate and private key to PKCS12 format and cleared legacy keys.")
        } catch {
            debugLog("[Keychain] Failed to migrate legacy certificate to PKCS12 format: \(error)")
        }
    }
    
    public func clearCertificates()
    {
        // Legacy
        self.signingCertificatePrivateKey = nil
        self.signingCertificateSerialNumber = nil

        self.signingCertificate = nil
        self.signingCertificatePassword = nil
        
        debugLog("[Keychain] Cleared signing certificate & private key from Keychain.")
    }
    
    public func clearSignInInfo(keepAnisetteData: Bool = true)
    {
        debugLog("[Keychain] Clearing sign-in info from Keychain (keepAnisetteData: \(keepAnisetteData))...")
        
        self.appleIDEmailAddress = nil
        self.appleIDPassword = nil
        self.appleIDAdsid = nil
        self.appleIDXcodeToken = nil
        debugLog("[Keychain] Cleared Apple ID credentials & tokens (email, password, adsid, xcodeToken).")

        if !keepAnisetteData {
            self.adiPb = nil
            debugLog("[Keychain] Cleared Anisette ADI data (adiPb).")
        } else {
            debugLog("[Keychain] Preserved Anisette ADI data (adiPb).")
        }
        
        debugLog("[Keychain] Cleared sign-in info from Keychain.")
    }

    public func clearAll()
    {
        debugLog("[Keychain] Clearing all Keychain items related to this instance...")
        try? self.keychain.removeAll()
        debugLog("[Keychain] All Keychain items cleared.")
    }
}

public struct StoredAccountCredentials: Codable, Equatable, Sendable, Identifiable {
    public var id: String { normalizedAppleID }
    public var appleID: String
    public var normalizedAppleID: String
    public var accountIdentifier: String?
    public var firstName: String?
    public var lastName: String?
    public var teamIdentifier: String?
    public var teamName: String?
    public var teamTypeRawValue: Int?
    public var password: String?
    public var adsid: String?
    public var xcodeToken: String?
    public var certificateSerialNumber: String?
    public var certificateData: Data?
    public var certificatePassword: String?
    public var isDeviceRegistered: Bool?
    public var updatedAt: Date

    public var displayName: String {
        var components = PersonNameComponents()
        components.givenName = firstName
        components.familyName = lastName
        let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default).trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty {
            return formatted
        }
        if let teamName, !teamName.isEmpty {
            return teamName
        }
        return appleID
    }
}

